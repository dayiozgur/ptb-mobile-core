import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Aktivite Log Ekranı
///
/// Tüm sistem aktivitelerinin listesini gösterir.
/// Filtreleme ve detay görüntüleme özellikleri içerir.
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<ActivityLog> _activities = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 20;

  // Filters
  EntityType? _selectedEntityType;
  ActivityAction? _selectedAction;
  DateTimeRange? _dateRange;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadActivities({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
    }

    setState(() => _isLoading = true);

    try {
      final tenantId = tenantService.currentTenantId;
      if (tenantId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final activities = await activityService.getRecentActivities(
        tenantId,
        limit: _limit,
        offset: _offset,
        entityType: _selectedEntityType,
        action: _selectedAction,
        useCache: !refresh,
      );

      setState(() {
        if (refresh) {
          _activities = activities;
        } else {
          _activities = activities;
        }
        _hasMore = activities.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load activities', e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _offset += _limit;

    try {
      final tenantId = tenantService.currentTenantId;
      if (tenantId == null) {
        setState(() => _isLoadingMore = false);
        return;
      }

      final activities = await activityService.getRecentActivities(
        tenantId,
        limit: _limit,
        offset: _offset,
        entityType: _selectedEntityType,
        action: _selectedAction,
        useCache: false,
      );

      setState(() {
        _activities.addAll(activities);
        _hasMore = activities.length >= _limit;
        _isLoadingMore = false;
      });
    } catch (e) {
      Logger.error('Failed to load more activities', e);
      setState(() => _isLoadingMore = false);
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FilterBottomSheet(
        selectedEntityType: _selectedEntityType,
        selectedAction: _selectedAction,
        dateRange: _dateRange,
        onApply: (entityType, action, dateRange) {
          setState(() {
            _selectedEntityType = entityType;
            _selectedAction = action;
            _dateRange = dateRange;
          });
          Navigator.pop(context);
          _loadActivities(refresh: true);
        },
        onClear: () {
          setState(() {
            _selectedEntityType = null;
            _selectedAction = null;
            _dateRange = null;
          });
          Navigator.pop(context);
          _loadActivities(refresh: true);
        },
      ),
    );
  }

  void _showActivityDetail(ActivityLog activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ActivityDetailSheet(activity: activity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _selectedEntityType != null ||
        _selectedAction != null ||
        _dateRange != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivite Geçmişi'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilters,
              ),
              if (hasFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadActivities(refresh: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _activities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Aktivite bulunamadı',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Henüz kayıtlı aktivite yok',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Group activities by date
    final groupedActivities = _groupByDate(_activities);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: groupedActivities.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == groupedActivities.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final entry = groupedActivities.entries.elementAt(index);
        return _buildDateGroup(entry.key, entry.value);
      },
    );
  }

  Map<String, List<ActivityLog>> _groupByDate(List<ActivityLog> activities) {
    final grouped = <String, List<ActivityLog>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final activity in activities) {
      final activityDate = DateTime(
        activity.createdAt.year,
        activity.createdAt.month,
        activity.createdAt.day,
      );

      String dateKey;
      if (activityDate == today) {
        dateKey = 'Bugün';
      } else if (activityDate == yesterday) {
        dateKey = 'Dün';
      } else {
        dateKey = '${activityDate.day}.${activityDate.month}.${activityDate.year}';
      }

      grouped.putIfAbsent(dateKey, () => []).add(activity);
    }

    return grouped;
  }

  Widget _buildDateGroup(String date, List<ActivityLog> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            date,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
          ),
        ),
        ...activities.map((activity) => _buildActivityItem(activity)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActivityItem(ActivityLog activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showActivityDetail(activity),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getActionColor(activity.action).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getActionIcon(activity.action),
                  color: _getActionColor(activity.action),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.displayText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getEntityIcon(activity.entityType),
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activity.entityType.displayName,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activity.relativeTime,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (activity.userName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            activity.userName!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getActionIcon(ActivityAction action) {
    switch (action) {
      case ActivityAction.create:
        return Icons.add_circle_outline;
      case ActivityAction.read:
        return Icons.visibility;
      case ActivityAction.update:
        return Icons.edit;
      case ActivityAction.delete:
        return Icons.delete_outline;
      case ActivityAction.login:
        return Icons.login;
      case ActivityAction.logout:
        return Icons.logout;
      case ActivityAction.export_:
        return Icons.download;
      case ActivityAction.import_:
        return Icons.upload;
      case ActivityAction.enable:
        return Icons.check_circle_outline;
      case ActivityAction.disable:
        return Icons.block;
    }
  }

  Color _getActionColor(ActivityAction action) {
    switch (action) {
      case ActivityAction.create:
        return Colors.green;
      case ActivityAction.read:
        return Colors.blue;
      case ActivityAction.update:
        return Colors.orange;
      case ActivityAction.delete:
        return Colors.red;
      case ActivityAction.login:
        return Colors.green;
      case ActivityAction.logout:
        return Colors.grey;
      case ActivityAction.export_:
        return Colors.purple;
      case ActivityAction.import_:
        return Colors.indigo;
      case ActivityAction.enable:
        return Colors.green;
      case ActivityAction.disable:
        return Colors.red;
    }
  }

  IconData _getEntityIcon(EntityType type) {
    switch (type) {
      case EntityType.tenant:
        return Icons.business;
      case EntityType.organization:
        return Icons.corporate_fare;
      case EntityType.site:
        return Icons.location_city;
      case EntityType.unit:
        return Icons.widgets;
      case EntityType.user:
        return Icons.person;
      case EntityType.invitation:
        return Icons.mail;
      case EntityType.profile:
        return Icons.account_circle;
      case EntityType.settings:
        return Icons.settings;
      case EntityType.other:
        return Icons.more_horiz;
    }
  }
}

/// Filter Bottom Sheet
class _FilterBottomSheet extends StatefulWidget {
  final EntityType? selectedEntityType;
  final ActivityAction? selectedAction;
  final DateTimeRange? dateRange;
  final Function(EntityType?, ActivityAction?, DateTimeRange?) onApply;
  final VoidCallback onClear;

  const _FilterBottomSheet({
    this.selectedEntityType,
    this.selectedAction,
    this.dateRange,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  EntityType? _entityType;
  ActivityAction? _action;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _entityType = widget.selectedEntityType;
    _action = widget.selectedAction;
    _dateRange = widget.dateRange;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtrele',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: widget.onClear,
                child: const Text('Temizle'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Entity Type Filter
          Text(
            'Varlık Türü',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EntityType.values.map((type) {
              final isSelected = _entityType == type;
              return FilterChip(
                label: Text(type.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _entityType = selected ? type : null);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Action Filter
          Text(
            'İşlem Türü',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ActivityAction.values.map((action) {
              final isSelected = _action == action;
              return FilterChip(
                label: Text(action.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _action = selected ? action : null);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onApply(_entityType, _action, _dateRange),
              child: const Text('Uygula'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Activity Detail Sheet
class _ActivityDetailSheet extends StatelessWidget {
  final ActivityLog activity;

  const _ActivityDetailSheet({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aktivite Detayı',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),

          _buildDetailRow(context, 'İşlem', activity.action.displayName),
          _buildDetailRow(context, 'Varlık', activity.entityType.displayName),
          _buildDetailRow(context, 'Varlık ID', activity.entityId),
          if (activity.entityName != null)
            _buildDetailRow(context, 'Varlık Adı', activity.entityName!),
          if (activity.userName != null)
            _buildDetailRow(context, 'Kullanıcı', activity.userName!),
          if (activity.userEmail != null)
            _buildDetailRow(context, 'E-posta', activity.userEmail!),
          _buildDetailRow(
            context,
            'Tarih',
            '${activity.createdAt.day}.${activity.createdAt.month}.${activity.createdAt.year} '
            '${activity.createdAt.hour.toString().padLeft(2, '0')}:'
            '${activity.createdAt.minute.toString().padLeft(2, '0')}',
          ),
          if (activity.ipAddress != null)
            _buildDetailRow(context, 'IP Adresi', activity.ipAddress!),

          // Changes
          if (activity.oldValues != null || activity.newValues != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Değişiklikler',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (activity.oldValues != null)
              _buildJsonView(context, 'Eski Değerler', activity.oldValues!),
            if (activity.newValues != null)
              _buildJsonView(context, 'Yeni Değerler', activity.newValues!),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonView(
    BuildContext context,
    String title,
    Map<String, dynamic> data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            data.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
