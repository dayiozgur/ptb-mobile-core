import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Yapılacaklar Ana Ekranı
///
/// Tüm yapılacakları listeler, filtreler ve arama imkanı sunar.
class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<TodoItem> _allTodos = [];
  List<TodoItem> _filteredTodos = [];

  // Filtreler
  TodoStatus? _selectedStatus;
  TodoPriority? _selectedPriority;
  String _searchQuery = '';
  _SortOption _sortOption = _SortOption.createdAtDesc;

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
      final todos = await todoService.getTodos();

      if (mounted) {
        setState(() {
          _allTodos = todos;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load todos', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Yapılacaklar yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    var filtered = List<TodoItem>.from(_allTodos);

    // Status filtresi
    if (_selectedStatus != null) {
      filtered = filtered.where((t) => t.status == _selectedStatus).toList();
    }

    // Priority filtresi
    if (_selectedPriority != null) {
      filtered = filtered.where((t) => t.priority == _selectedPriority).toList();
    }

    // Arama filtresi
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        final title = t.title.toLowerCase();
        final description = (t.description ?? '').toLowerCase();
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    // Sıralama
    switch (_sortOption) {
      case _SortOption.createdAtDesc:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortOption.createdAtAsc:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortOption.priorityDesc:
        filtered.sort((a, b) =>
            TodoPriority.values.indexOf(b.priority).compareTo(
                TodoPriority.values.indexOf(a.priority)));
      case _SortOption.priorityAsc:
        filtered.sort((a, b) =>
            TodoPriority.values.indexOf(a.priority).compareTo(
                TodoPriority.values.indexOf(b.priority)));
      case _SortOption.dueDateAsc:
        filtered.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
    }

    _filteredTodos = filtered;
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

  void _showFilterSheet() {
    final brightness = Theme.of(context).brightness;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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

                // Başlık
                Text(
                  'Filtreler',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Durum Filtresi
                _buildFilterSection(
                  'Durum',
                  [
                    _FilterOption(
                      label: 'Tümü',
                      isSelected: _selectedStatus == null,
                      color: AppColors.primary,
                      onTap: () => _updateFilter(clearStatus: true),
                    ),
                    ...TodoStatus.values.map((s) => _FilterOption(
                          label: s.label,
                          isSelected: _selectedStatus == s,
                          color: _getStatusColor(s),
                          onTap: () => _updateFilter(status: s),
                        )),
                  ],
                  brightness,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Öncelik Filtresi
                _buildFilterSection(
                  'Öncelik',
                  [
                    _FilterOption(
                      label: 'Tümü',
                      isSelected: _selectedPriority == null,
                      color: AppColors.primary,
                      onTap: () => _updateFilter(clearPriority: true),
                    ),
                    ...TodoPriority.values.map((p) => _FilterOption(
                          label: p.label,
                          isSelected: _selectedPriority == p,
                          color: _getPriorityColor(p),
                          onTap: () => _updateFilter(priority: p),
                        )),
                  ],
                  brightness,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Sıralama
                Text(
                  'Sıralama',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._SortOption.values.map((option) => ListTile(
                      title: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      leading: Radio<_SortOption>(
                        value: option,
                        groupValue: _sortOption,
                        onChanged: (value) {
                          setState(() {
                            _sortOption = value!;
                            _applyFilters();
                          });
                          Navigator.pop(context);
                        },
                        activeColor: AppColors.primary,
                      ),
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        setState(() {
                          _sortOption = option;
                          _applyFilters();
                        });
                        Navigator.pop(context);
                      },
                    )),

                const SizedBox(height: AppSpacing.lg),

                // Filtreleri Sıfırla
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                        _selectedPriority = null;
                        _sortOption = _SortOption.createdAtDesc;
                        _searchQuery = '';
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    ),
                    child: const Text('Filtreleri Sıfırla'),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(
      String title, List<_FilterOption> options, Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(brightness),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options
              .map((o) => _FilterChip(
                    label: o.label,
                    isSelected: o.isSelected,
                    color: o.color,
                    onTap: () {
                      o.onTap();
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  void _updateFilter({
    TodoStatus? status,
    TodoPriority? priority,
    bool clearStatus = false,
    bool clearPriority = false,
  }) {
    setState(() {
      if (status != null || clearStatus) {
        _selectedStatus = status;
      }
      if (priority != null || clearPriority) {
        _selectedPriority = priority;
      }
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Aktif filtre sayısı
    int activeFilterCount = 0;
    if (_selectedStatus != null) activeFilterCount++;
    if (_selectedPriority != null) activeFilterCount++;
    if (_sortOption != _SortOption.createdAtDesc) activeFilterCount++;

    return AppScaffold(
      title: 'Yapılacaklar',
      onBack: () => context.go('/home'),
      actions: [
        // Filtre butonu
        Stack(
          children: [
            AppIconButton(
              icon: Icons.filter_list,
              onPressed: _showFilterSheet,
            ),
            if (activeFilterCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      activeFilterCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/todos/new'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: Column(
        children: [
          // Arama Çubuğu
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: AppSearchBar(
              placeholder: 'Yapılacak ara...',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),
          ),

          // Özet istatistikler
          if (!_isLoading && _errorMessage == null) _buildStats(brightness),

          const SizedBox(height: AppSpacing.sm),

          // Liste
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildContent(brightness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(Brightness brightness) {
    final pending =
        _allTodos.where((t) => t.status == TodoStatus.pending).length;
    final overdue = _allTodos.where((t) => t.isOverdue).length;

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Row(
        children: [
          _StatBadge(
            label: 'Bekleyen',
            count: pending,
            color: AppColors.info,
          ),
          const SizedBox(width: AppSpacing.sm),
          if (overdue > 0)
            _StatBadge(
              label: 'Geciken',
              count: overdue,
              color: AppColors.error,
            ),
          const Spacer(),
          Text(
            '${_filteredTodos.length}/${_allTodos.length}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Brightness brightness) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    if (_filteredTodos.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.checklist_outlined,
          title: _allTodos.isEmpty ? 'Yapılacak Yok' : 'Sonuç Bulunamadı',
          message: _allTodos.isEmpty
              ? 'Henüz yapılacak oluşturulmamış.'
              : 'Arama kriterlerinize uygun yapılacak bulunamadı.',
          actionLabel: _allTodos.isEmpty ? 'Yeni Yapılacak Oluştur' : null,
          onAction:
              _allTodos.isEmpty ? () => context.push('/todos/new') : null,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      itemCount: _filteredTodos.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final todo = _filteredTodos[index];
        return _TodoCard(
          todo: todo,
          statusColor: _getStatusColor(todo.status),
          priorityColor: _getPriorityColor(todo.priority),
          onTap: () => context.push('/todos/${todo.id}'),
        );
      },
    );
  }
}

class _TodoCard extends StatelessWidget {
  final TodoItem todo;
  final Color statusColor;
  final Color priorityColor;
  final VoidCallback onTap;

  const _TodoCard({
    required this.todo,
    required this.statusColor,
    required this.priorityColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol renk çubuğu ve ikon
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    todo.isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst satır - gecikme uyarısı
                  if (todo.isOverdue)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 12, color: AppColors.error),
                            const SizedBox(width: 2),
                            Text(
                              'Gecikmiş',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Başlık
                  Text(
                    todo.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(brightness),
                      decoration:
                          todo.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (todo.description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      todo.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(brightness),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.sm),

                  // Badge'ler
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          todo.status.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      // Priority badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          todo.priority.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: priorityColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Alt bilgi satırı
                  Row(
                    children: [
                      if (todo.assignedToName != null) ...[
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppColors.textSecondary(brightness),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            todo.assignedToName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(brightness),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (todo.dueDate != null) ...[
                        Icon(
                          Icons.event_outlined,
                          size: 14,
                          color: todo.isOverdue
                              ? AppColors.error
                              : AppColors.textSecondary(brightness),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(todo.dueDate!),
                          style: TextStyle(
                            fontSize: 12,
                            color: todo.isOverdue
                                ? AppColors.error
                                : AppColors.textSecondary(brightness),
                            fontWeight:
                                todo.isOverdue ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right,
              color: AppColors.systemGray,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return 'Bugün';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays == -1) {
      return 'Yarın';
    } else if (diff.inDays < 0 && diff.inDays > -7) {
      return '${-diff.inDays} gün sonra';
    } else if (diff.inDays > 0 && diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppColors.systemGray6,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? color
                : AppColors.textSecondary(Theme.of(context).brightness),
          ),
        ),
      ),
    );
  }
}

class _FilterOption {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  _FilterOption({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });
}

enum _SortOption {
  createdAtDesc,
  createdAtAsc,
  priorityDesc,
  priorityAsc,
  dueDateAsc;

  String get label {
    switch (this) {
      case _SortOption.createdAtDesc:
        return 'En Yeni';
      case _SortOption.createdAtAsc:
        return 'En Eski';
      case _SortOption.priorityDesc:
        return 'Öncelik (Yüksek \u2192 Düşük)';
      case _SortOption.priorityAsc:
        return 'Öncelik (Düşük \u2192 Yüksek)';
      case _SortOption.dueDateAsc:
        return 'Bitiş Tarihine Göre';
    }
  }
}
