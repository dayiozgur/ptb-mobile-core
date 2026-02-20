import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Yapılacak Detay Ekranı
///
/// Seçilen yapılacağın tüm detaylarını gösterir.
/// Tamamlama, iptal ve silme işlemleri yapılabilir.
class TodoDetailScreen extends StatefulWidget {
  final String todoId;

  const TodoDetailScreen({
    super.key,
    required this.todoId,
  });

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  TodoItem? _todo;
  List<TodoShare> _shares = [];

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
      todoService.setTenant(tenantId);
    }

    final userId = authService.currentUser?.id;
    if (userId != null) {
      todoService.setUser(userId);
    }

    try {
      final todo = await todoService.getTodo(widget.todoId);
      List<TodoShare> shares = [];

      if (todo != null) {
        try {
          shares = await todoService.getShares(widget.todoId);
        } catch (e) {
          Logger.error('Failed to load todo shares', e);
        }
      }

      if (mounted) {
        setState(() {
          _todo = todo;
          _shares = shares;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load todo', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Yapılacak yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeTodo() async {
    setState(() => _isActionLoading = true);

    try {
      await todoService.completeTodo(widget.todoId);
      await _loadData();
      if (mounted) {
        AppSnackbar.success(context, message: 'Yapılacak tamamlandı');
      }
    } catch (e) {
      Logger.error('Failed to complete todo', e);
      if (mounted) {
        AppSnackbar.error(context, message: 'Tamamlama işlemi başarısız');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _cancelTodo() async {
    setState(() => _isActionLoading = true);

    try {
      await todoService.updateTodo(
        widget.todoId,
        status: TodoStatus.cancelled,
      );
      await _loadData();
      if (mounted) {
        AppSnackbar.success(context, message: 'Yapılacak iptal edildi');
      }
    } catch (e) {
      Logger.error('Failed to cancel todo', e);
      if (mounted) {
        AppSnackbar.error(context, message: 'İptal işlemi başarısız');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _deleteTodo() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yapılacağı Sil'),
        content: const Text(
            'Bu yapılacağı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isActionLoading = true);

      try {
        await todoService.deleteTodo(widget.todoId);
        if (mounted) {
          AppSnackbar.success(context, message: 'Yapılacak silindi');
          context.go('/todos');
        }
      } catch (e) {
        Logger.error('Failed to delete todo', e);
        if (mounted) {
          AppSnackbar.error(context, message: 'Silme işlemi başarısız');
          setState(() => _isActionLoading = false);
        }
      }
    }
  }

  Color _getStatusColor(TodoStatus status) {
    switch (status) {
      case TodoStatus.pending:
        return AppColors.info;
      case TodoStatus.inProgress:
        return AppColors.warning;
      case TodoStatus.completed:
        return AppColors.success;
      case TodoStatus.cancelled:
        return AppColors.systemGray;
    }
  }

  Color _getPriorityColor(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.low:
        return AppColors.systemGray;
      case TodoPriority.medium:
        return AppColors.info;
      case TodoPriority.high:
        return AppColors.warning;
      case TodoPriority.urgent:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: 'Yapılacak Detayı',
      onBack: () => context.go('/todos'),
      actions: [
        if (_todo != null && _todo!.status.isOpen)
          AppIconButton(
            icon: Icons.edit,
            onPressed: () => context.push('/todos/${widget.todoId}/edit'),
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
              : _todo == null
                  ? Center(
                      child: AppEmptyState(
                        icon: Icons.checklist_outlined,
                        title: 'Yapılacak Bulunamadı',
                        message: 'İstenen yapılacak bulunamadı.',
                      ),
                    )
                  : _buildContent(brightness),
    );
  }

  Widget _buildContent(Brightness brightness) {
    final todo = _todo!;
    final statusColor = _getStatusColor(todo.status);
    final priorityColor = _getPriorityColor(todo.priority);

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
                _buildHeader(todo, statusColor, priorityColor, brightness),

                const SizedBox(height: AppSpacing.lg),

                // Detay Bilgileri
                _buildDetailSection(todo, brightness),

                const SizedBox(height: AppSpacing.lg),

                // Paylaşımlar
                if (_shares.isNotEmpty) ...[
                  _buildSharesSection(brightness),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Silme butonu
                if (todo.status.isOpen)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isActionLoading ? null : _deleteTodo,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Yapılacağı Sil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm),
                      ),
                    ),
                  ),

                // Alt boşluk (aksiyon butonları için)
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),

        // Aksiyon butonları
        if (todo.status.isOpen)
          Positioned(
            left: AppSpacing.screenHorizontal,
            right: AppSpacing.screenHorizontal,
            bottom: AppSpacing.md,
            child: SafeArea(
              child: Row(
                children: [
                  // İptal Et butonu
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isActionLoading ? null : _cancelTodo,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('İptal Et'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.systemGray,
                        side: BorderSide(color: AppColors.systemGray),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Tamamla butonu
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Tamamla',
                      icon: Icons.check_circle,
                      isLoading: _isActionLoading,
                      onPressed: _completeTodo,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(
    TodoItem todo,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        todo.status.label,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    todo.priority.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Başlık
            Text(
              todo.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(brightness),
                decoration:
                    todo.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),

            if (todo.description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                todo.description!,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary(brightness),
                  height: 1.4,
                ),
              ),
            ],

            // Gecikme uyarısı
            if (todo.isOverdue) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Bu yapılacak gecikmiş durumda!',
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

  Widget _buildDetailSection(TodoItem todo, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detay Bilgileri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Oluşturulma',
              value: _formatDateTime(todo.createdAt),
            ),
            if (todo.dueDate != null)
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Bitiş Tarihi',
                value: _formatDateTime(todo.dueDate!),
                valueColor: todo.isOverdue ? AppColors.error : null,
              ),
            if (todo.completedAt != null)
              _DetailRow(
                icon: Icons.check_circle_outline,
                label: 'Tamamlanma',
                value: _formatDateTime(todo.completedAt!),
                valueColor: AppColors.success,
              ),
            if (todo.assignedToName != null)
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Atanan Kişi',
                value: todo.assignedToName!,
              ),
            if (todo.updatedAt != null)
              _DetailRow(
                icon: Icons.update,
                label: 'Son Güncelleme',
                value: _formatDateTime(todo.updatedAt!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharesSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Paylaşımlar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_shares.length}',
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
            ..._shares.map((share) => _ShareItem(share: share)),
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

class _ShareItem extends StatelessWidget {
  final TodoShare share;

  const _ShareItem({required this.share});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Paylaşım hedefi belirleme
    String shareTarget = 'Bilinmiyor';
    IconData shareIcon = Icons.person_outline;

    if (share.sharedWithUser != null) {
      shareTarget = share.sharedWithUser!;
      shareIcon = Icons.person_outline;
    } else if (share.sharedWithTeam != null) {
      shareTarget = share.sharedWithTeam!;
      shareIcon = Icons.group_outlined;
    } else if (share.sharedWithDepartment != null) {
      shareTarget = share.sharedWithDepartment!;
      shareIcon = Icons.business_outlined;
    }

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
            child: Icon(shareIcon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shareTarget,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                Row(
                  children: [
                    if (share.canEdit)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: Text(
                          'Düzenleyebilir',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    if (share.canDelete)
                      Text(
                        'Silebilir',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                        ),
                      ),
                    if (!share.canEdit && !share.canDelete)
                      Text(
                        'Salt okunur',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (share.sharedAt != null)
            Text(
              '${share.sharedAt!.day.toString().padLeft(2, '0')}/${share.sharedAt!.month.toString().padLeft(2, '0')}/${share.sharedAt!.year}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(brightness),
              ),
            ),
        ],
      ),
    );
  }
}
