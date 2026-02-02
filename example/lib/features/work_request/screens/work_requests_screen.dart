import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// İş Talepleri Ana Ekranı
///
/// Tüm iş taleplerini listeler, filtreler ve arama imkanı sunar.
class WorkRequestsScreen extends StatefulWidget {
  const WorkRequestsScreen({super.key});

  @override
  State<WorkRequestsScreen> createState() => _WorkRequestsScreenState();
}

class _WorkRequestsScreenState extends State<WorkRequestsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<WorkRequest> _allRequests = [];
  List<WorkRequest> _filteredRequests = [];

  // Filtreler
  WorkRequestStatus? _selectedStatus;
  WorkRequestType? _selectedType;
  WorkRequestPriority? _selectedPriority;
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
      workRequestService.setTenant(tenantId);
    }

    try {
      final requests = await workRequestService.getAll();

      if (mounted) {
        setState(() {
          _allRequests = requests;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load work requests', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'İş talepleri yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    var filtered = List<WorkRequest>.from(_allRequests);

    // Status filtresi
    if (_selectedStatus != null) {
      filtered = filtered.where((r) => r.status == _selectedStatus).toList();
    }

    // Type filtresi
    if (_selectedType != null) {
      filtered = filtered.where((r) => r.type == _selectedType).toList();
    }

    // Priority filtresi
    if (_selectedPriority != null) {
      filtered = filtered.where((r) => r.priority == _selectedPriority).toList();
    }

    // Arama filtresi
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        final title = r.title.toLowerCase();
        final description = (r.description ?? '').toLowerCase();
        final number = (r.requestNumber ?? '').toLowerCase();
        return title.contains(query) ||
            description.contains(query) ||
            number.contains(query);
      }).toList();
    }

    // Sıralama
    switch (_sortOption) {
      case _SortOption.createdAtDesc:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortOption.createdAtAsc:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortOption.priorityDesc:
        filtered.sort((a, b) => b.priority.level.compareTo(a.priority.level));
      case _SortOption.priorityAsc:
        filtered.sort((a, b) => a.priority.level.compareTo(b.priority.level));
      case _SortOption.statusAsc:
        filtered.sort((a, b) => a.status.index.compareTo(b.status.index));
    }

    _filteredRequests = filtered;
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

  IconData _getTypeIcon(WorkRequestType type) {
    switch (type) {
      case WorkRequestType.breakdown:
        return Icons.warning_amber_rounded;
      case WorkRequestType.maintenance:
        return Icons.build_outlined;
      case WorkRequestType.service:
        return Icons.support_agent;
      case WorkRequestType.inspection:
        return Icons.search;
      case WorkRequestType.installation:
        return Icons.add_box_outlined;
      case WorkRequestType.modification:
        return Icons.edit_note;
      case WorkRequestType.general:
        return Icons.assignment_outlined;
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
                      onTap: () => _updateFilter(status: null),
                    ),
                    ...WorkRequestStatus.values.map((s) => _FilterOption(
                          label: s.label,
                          isSelected: _selectedStatus == s,
                          color: _getStatusColor(s),
                          onTap: () => _updateFilter(status: s),
                        )),
                  ],
                  brightness,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Tip Filtresi
                _buildFilterSection(
                  'Talep Tipi',
                  [
                    _FilterOption(
                      label: 'Tümü',
                      isSelected: _selectedType == null,
                      color: AppColors.primary,
                      onTap: () => _updateFilter(type: null, clearType: true),
                    ),
                    ...WorkRequestType.values.map((t) => _FilterOption(
                          label: t.label,
                          isSelected: _selectedType == t,
                          color: AppColors.primary,
                          onTap: () => _updateFilter(type: t),
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
                      onTap: () => _updateFilter(priority: null, clearPriority: true),
                    ),
                    ...WorkRequestPriority.values.map((p) => _FilterOption(
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
                        _selectedType = null;
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
    WorkRequestStatus? status,
    WorkRequestType? type,
    WorkRequestPriority? priority,
    bool clearType = false,
    bool clearPriority = false,
  }) {
    setState(() {
      if (status != null || _selectedStatus != null) {
        _selectedStatus = status;
      }
      if (type != null || clearType) {
        _selectedType = type;
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
    if (_selectedType != null) activeFilterCount++;
    if (_selectedPriority != null) activeFilterCount++;
    if (_sortOption != _SortOption.createdAtDesc) activeFilterCount++;

    return AppScaffold(
      title: 'İş Talepleri',
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
        onPressed: () => context.push('/work-requests/new'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: Column(
        children: [
          // Arama Çubuğu
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: AppSearchBar(
              placeholder: 'Talep ara...',
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
    final pending = _allRequests.where((r) => r.status == WorkRequestStatus.submitted).length;
    final inProgress = _allRequests.where((r) => r.status.isActionable).length;
    final overdue = _allRequests.where((r) => r.isOverdue).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Row(
        children: [
          _StatBadge(
            label: 'Bekleyen',
            count: pending,
            color: AppColors.info,
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatBadge(
            label: 'Devam Eden',
            count: inProgress,
            color: AppColors.warning,
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
            '${_filteredRequests.length}/${_allRequests.length}',
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

    if (_filteredRequests.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.assignment_outlined,
          title: _allRequests.isEmpty ? 'İş Talebi Yok' : 'Sonuç Bulunamadı',
          message: _allRequests.isEmpty
              ? 'Henüz iş talebi oluşturulmamış.'
              : 'Arama kriterlerinize uygun talep bulunamadı.',
          actionLabel: _allRequests.isEmpty ? 'Yeni Talep Oluştur' : null,
          onAction: _allRequests.isEmpty
              ? () => context.push('/work-requests/new')
              : null,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      itemCount: _filteredRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final request = _filteredRequests[index];
        return _WorkRequestCard(
          request: request,
          statusColor: _getStatusColor(request.status),
          priorityColor: _getPriorityColor(request.priority),
          typeIcon: _getTypeIcon(request.type),
          onTap: () => context.push('/work-requests/${request.id}'),
        );
      },
    );
  }
}

class _WorkRequestCard extends StatelessWidget {
  final WorkRequest request;
  final Color statusColor;
  final Color priorityColor;
  final IconData typeIcon;
  final VoidCallback onTap;

  const _WorkRequestCard({
    required this.request,
    required this.statusColor,
    required this.priorityColor,
    required this.typeIcon,
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
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: priorityColor, size: 22),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor,
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
                  // Başlık satırı
                  Row(
                    children: [
                      if (request.requestNumber != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.systemGray6,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            request.requestNumber!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      if (request.isOverdue)
                        Container(
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
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // Başlık
                  Text(
                    request.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(brightness),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (request.description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      request.description!,
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
                          request.status.label,
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
                          request.priority.label,
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
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.textSecondary(brightness),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.requestedByName ?? 'Bilinmiyor',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(brightness),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.textSecondary(brightness),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(request.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ],
                  ),

                  // Konum bilgisi
                  if (request.locationSummary != '-') ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textSecondary(brightness),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            request.locationSummary,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(brightness),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
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
      return 'Bugün ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
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
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.systemGray6,
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
  statusAsc;

  String get label {
    switch (this) {
      case _SortOption.createdAtDesc:
        return 'En Yeni';
      case _SortOption.createdAtAsc:
        return 'En Eski';
      case _SortOption.priorityDesc:
        return 'Öncelik (Yüksek → Düşük)';
      case _SortOption.priorityAsc:
        return 'Öncelik (Düşük → Yüksek)';
      case _SortOption.statusAsc:
        return 'Duruma Göre';
    }
  }
}
