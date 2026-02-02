import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// İş Talebi Detay Ekranı
///
/// Seçilen iş talebinin tüm detaylarını gösterir.
/// Durum geçişleri, atama ve onay işlemleri yapılabilir.
class WorkRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const WorkRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<WorkRequestDetailScreen> createState() => _WorkRequestDetailScreenState();
}

class _WorkRequestDetailScreenState extends State<WorkRequestDetailScreen> {
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  WorkRequest? _request;

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

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      workRequestService.setTenant(tenantId);
    }

    try {
      final request = await workRequestService.getById(widget.requestId);

      if (mounted) {
        setState(() {
          _request = request;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load work request', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'İş talebi yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performAction(String action, Future<void> Function() actionFn) async {
    setState(() => _isActionLoading = true);

    try {
      await actionFn();
      await _loadData();
      if (mounted) {
        AppSnackbar.success(context, message: '$action işlemi başarılı');
      }
    } catch (e) {
      Logger.error('Action failed: $action', e);
      if (mounted) {
        AppSnackbar.error(context, message: '$action işlemi başarısız');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  void _showStatusActions() {
    if (_request == null) return;

    final transitions = _request!.allowedTransitions;
    if (transitions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.systemGray4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Durum Değiştir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(Theme.of(context).brightness),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...transitions.map((status) => _StatusActionTile(
                    status: status,
                    onTap: () {
                      Navigator.pop(context);
                      _handleStatusChange(status);
                    },
                  )),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleStatusChange(WorkRequestStatus newStatus) async {
    switch (newStatus) {
      case WorkRequestStatus.submitted:
        await _performAction('Gönder', () => workRequestService.submit(widget.requestId));
      case WorkRequestStatus.approved:
        await _showApprovalDialog(true);
      case WorkRequestStatus.rejected:
        await _showApprovalDialog(false);
      case WorkRequestStatus.assigned:
        await _showAssignDialog();
      case WorkRequestStatus.inProgress:
        await _performAction('Başlat', () => workRequestService.startWork(widget.requestId));
      case WorkRequestStatus.onHold:
        await _performAction('Beklet', () => workRequestService.putOnHold(widget.requestId));
      case WorkRequestStatus.completed:
        await _showCompleteDialog();
      case WorkRequestStatus.cancelled:
        await _performAction('İptal Et', () => workRequestService.cancel(widget.requestId));
      case WorkRequestStatus.closed:
        await _performAction('Kapat', () => workRequestService.close(widget.requestId));
      default:
        break;
    }
  }

  Future<void> _showApprovalDialog(bool approve) async {
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Talebi Onayla' : 'Talebi Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(approve
                ? 'Bu talebi onaylamak istediğinize emin misiniz?'
                : 'Bu talebi reddetmek istediğinize emin misiniz?'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: approve ? 'Onay Notu (opsiyonel)' : 'Red Nedeni',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AppColors.success : AppColors.error,
            ),
            child: Text(approve ? 'Onayla' : 'Reddet'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (approve) {
        await _performAction(
          'Onayla',
          () => workRequestService.approve(widget.requestId, note: noteController.text),
        );
      } else {
        await _performAction(
          'Reddet',
          () => workRequestService.reject(widget.requestId, reason: noteController.text),
        );
      }
    }
  }

  Future<void> _showAssignDialog() async {
    // TODO: Kullanıcı seçimi için dialog göster
    AppSnackbar.info(context, message: 'Atama özelliği yakında eklenecek');
  }

  Future<void> _showCompleteDialog() async {
    final durationController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Talebi Tamamla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu talebi tamamlamak istediğinize emin misiniz?'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harcanan Süre (dakika)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Tamamla'),
          ),
        ],
      ),
    );

    if (result == true) {
      final duration = int.tryParse(durationController.text);
      await _performAction(
        'Tamamla',
        () => workRequestService.complete(widget.requestId, actualDuration: duration),
      );
    }
  }

  Color _getStatusColor(WorkRequestStatus status) {
    switch (status) {
      case WorkRequestStatus.draft:
        return AppColors.systemGray;
      case WorkRequestStatus.submitted:
        return AppColors.info;
      case WorkRequestStatus.approved:
        return AppColors.success;
      case WorkRequestStatus.rejected:
        return AppColors.error;
      case WorkRequestStatus.assigned:
        return Colors.purple;
      case WorkRequestStatus.inProgress:
        return AppColors.warning;
      case WorkRequestStatus.onHold:
        return Colors.orange;
      case WorkRequestStatus.completed:
        return AppColors.success;
      case WorkRequestStatus.cancelled:
        return AppColors.systemGray;
      case WorkRequestStatus.closed:
        return AppColors.systemGray3;
    }
  }

  Color _getPriorityColor(WorkRequestPriority priority) {
    switch (priority) {
      case WorkRequestPriority.low:
        return AppColors.systemGray;
      case WorkRequestPriority.normal:
        return AppColors.info;
      case WorkRequestPriority.high:
        return AppColors.warning;
      case WorkRequestPriority.urgent:
        return Colors.orange;
      case WorkRequestPriority.critical:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: _request?.requestNumber ?? 'İş Talebi',
      onBack: () => context.go('/work-requests'),
      actions: [
        if (_request != null && _request!.isEditable)
          AppIconButton(
            icon: Icons.edit,
            onPressed: () => context.push('/work-requests/${widget.requestId}/edit'),
          ),
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(
                  child: AppErrorView(
                    message: _errorMessage!,
                    onRetry: _loadData,
                  ),
                )
              : _request == null
                  ? Center(
                      child: AppEmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'Talep Bulunamadı',
                        message: 'İstenen iş talebi bulunamadı.',
                      ),
                    )
                  : _buildContent(brightness),
    );
  }

  Widget _buildContent(Brightness brightness) {
    final request = _request!;
    final statusColor = _getStatusColor(request.status);
    final priorityColor = _getPriorityColor(request.priority);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık ve Durum
                _buildHeader(request, statusColor, priorityColor, brightness),

                const SizedBox(height: AppSpacing.lg),

                // Detay Bilgileri
                _buildDetailSection(request, brightness),

                const SizedBox(height: AppSpacing.lg),

                // Konum Bilgileri
                if (request.locationSummary != '-')
                  _buildLocationSection(request, brightness),

                if (request.locationSummary != '-')
                  const SizedBox(height: AppSpacing.lg),

                // Atama Bilgileri
                _buildAssignmentSection(request, brightness),

                const SizedBox(height: AppSpacing.lg),

                // Maliyet ve Süre
                _buildCostSection(request, brightness),

                const SizedBox(height: AppSpacing.lg),

                // Notlar
                if (request.notes.isNotEmpty) ...[
                  _buildNotesSection(request, brightness),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Ekler
                if (request.attachments.isNotEmpty) ...[
                  _buildAttachmentsSection(request, brightness),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Alt boşluk (FAB için)
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Aksiyon butonu
        if (request.allowedTransitions.isNotEmpty)
          Positioned(
            left: AppSpacing.screenHorizontal,
            right: AppSpacing.screenHorizontal,
            bottom: AppSpacing.md,
            child: SafeArea(
              child: AppButton(
                label: 'Durum Değiştir',
                icon: Icons.swap_horiz,
                isLoading: _isActionLoading,
                onPressed: _showStatusActions,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(
    WorkRequest request,
    Color statusColor,
    Color priorityColor,
    Brightness brightness,
  ) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge'ler
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        request.status.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.priority.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: priorityColor,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.systemGray6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.type.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Başlık
            Text(
              request.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(brightness),
              ),
            ),

            if (request.description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                request.description!,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary(brightness),
                  height: 1.4,
                ),
              ),
            ],

            // Gecikme uyarısı
            if (request.isOverdue) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Bu talep gecikmiş durumda!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(WorkRequest request, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Talep Bilgileri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              icon: Icons.tag,
              label: 'Talep No',
              value: request.requestNumber ?? '-',
            ),
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Talep Eden',
              value: request.requestedByName ?? '-',
            ),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Talep Tarihi',
              value: _formatDateTime(request.requestedAt),
            ),
            if (request.expectedCompletionDate != null)
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Beklenen Tarih',
                value: _formatDateTime(request.expectedCompletionDate!),
              ),
            if (request.actualCompletionDate != null)
              _DetailRow(
                icon: Icons.check_circle_outline,
                label: 'Tamamlanma',
                value: _formatDateTime(request.actualCompletionDate!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(WorkRequest request, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konum Bilgileri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (request.siteName != null)
              _DetailRow(
                icon: Icons.location_city,
                label: 'Site',
                value: request.siteName!,
              ),
            if (request.unitName != null)
              _DetailRow(
                icon: Icons.space_dashboard_outlined,
                label: 'Alan',
                value: request.unitName!,
              ),
            if (request.controllerName != null)
              _DetailRow(
                icon: Icons.developer_board,
                label: 'Cihaz',
                value: request.controllerName!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentSection(WorkRequest request, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atama ve Onay',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              icon: Icons.person_add_outlined,
              label: 'Atanan',
              value: request.assignedToName ?? 'Atanmadı',
            ),
            if (request.assignedAt != null)
              _DetailRow(
                icon: Icons.schedule,
                label: 'Atama Tarihi',
                value: _formatDateTime(request.assignedAt!),
              ),
            if (request.approvedByName != null)
              _DetailRow(
                icon: Icons.verified_outlined,
                label: 'Onaylayan',
                value: request.approvedByName!,
              ),
            if (request.approvedAt != null)
              _DetailRow(
                icon: Icons.schedule,
                label: 'Onay Tarihi',
                value: _formatDateTime(request.approvedAt!),
              ),
            if (request.approvalNote != null)
              _DetailRow(
                icon: Icons.note_outlined,
                label: 'Onay Notu',
                value: request.approvalNote!,
              ),
            if (request.rejectionReason != null)
              _DetailRow(
                icon: Icons.cancel_outlined,
                label: 'Red Nedeni',
                value: request.rejectionReason!,
                valueColor: AppColors.error,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSection(WorkRequest request, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Süre ve Maliyet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _CostCard(
                    title: 'Tahmini Süre',
                    value: request.estimatedDurationFormatted,
                    icon: Icons.timer_outlined,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _CostCard(
                    title: 'Gerçek Süre',
                    value: request.actualDurationFormatted,
                    icon: Icons.timer,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _CostCard(
                    title: 'Tahmini Maliyet',
                    value: request.estimatedCost != null
                        ? '${request.estimatedCost!.toStringAsFixed(2)} ${request.currency ?? "TRY"}'
                        : '-',
                    icon: Icons.attach_money,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _CostCard(
                    title: 'Gerçek Maliyet',
                    value: request.actualCost != null
                        ? '${request.actualCost!.toStringAsFixed(2)} ${request.currency ?? "TRY"}'
                        : '-',
                    icon: Icons.payments_outlined,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(WorkRequest request, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Notlar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${request.notes.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...request.notes.map((note) => _NoteItem(note: note)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection(WorkRequest request, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Ekler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${request.attachments.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...request.attachments.map((attachment) => _AttachmentItem(attachment: attachment)),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary(brightness)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.textPrimary(brightness),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _CostCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusActionTile extends StatelessWidget {
  final WorkRequestStatus status;
  final VoidCallback onTap;

  const _StatusActionTile({
    required this.status,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (status) {
      case WorkRequestStatus.submitted:
        return AppColors.info;
      case WorkRequestStatus.approved:
        return AppColors.success;
      case WorkRequestStatus.rejected:
        return AppColors.error;
      case WorkRequestStatus.assigned:
        return Colors.purple;
      case WorkRequestStatus.inProgress:
        return AppColors.warning;
      case WorkRequestStatus.onHold:
        return Colors.orange;
      case WorkRequestStatus.completed:
        return AppColors.success;
      case WorkRequestStatus.cancelled:
        return AppColors.systemGray;
      case WorkRequestStatus.closed:
        return AppColors.systemGray3;
      default:
        return AppColors.primary;
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case WorkRequestStatus.submitted:
        return Icons.send;
      case WorkRequestStatus.approved:
        return Icons.check_circle;
      case WorkRequestStatus.rejected:
        return Icons.cancel;
      case WorkRequestStatus.assigned:
        return Icons.person_add;
      case WorkRequestStatus.inProgress:
        return Icons.play_arrow;
      case WorkRequestStatus.onHold:
        return Icons.pause;
      case WorkRequestStatus.completed:
        return Icons.task_alt;
      case WorkRequestStatus.cancelled:
        return Icons.block;
      case WorkRequestStatus.closed:
        return Icons.lock;
      default:
        return Icons.arrow_forward;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getStatusIcon(), color: color),
      ),
      title: Text(
        status.label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.systemGray),
      onTap: onTap,
    );
  }
}

class _NoteItem extends StatelessWidget {
  final WorkRequestNote note;

  const _NoteItem({required this.note});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.systemGray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: note.authorName ?? 'U', size: AppAvatarSize.small),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.authorName ?? 'Bilinmiyor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    Text(
                      note.createdAt != null
                          ? '${note.createdAt!.day}/${note.createdAt!.month}/${note.createdAt!.year}'
                          : '',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  note.type.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            note.content,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentItem extends StatelessWidget {
  final WorkRequestAttachment attachment;

  const _AttachmentItem({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.systemGray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              attachment.isImage ? Icons.image : Icons.attach_file,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(brightness),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  attachment.fileSizeFormatted,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.download,
            onPressed: () {
              // TODO: Download attachment
            },
          ),
        ],
      ),
    );
  }
}
