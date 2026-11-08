import 'package:flutter/material.dart';

import '../../core/fixflow/fixflow_models.dart';
import '../../core/fixflow/fixflow_services.dart';
import '../widgets/feedback/app_empty_state.dart';
import 'fixflow_common.dart';

/// **Bakım planı** (`/fixflow/maintenance`) — salt-okuma liste; planlanan
/// tarihe göre (yakın önce). Durumlar `status_definitions` (maintenance).
class FixflowMaintenanceListScreen extends StatefulWidget {
  final DateTime Function()? clock;

  const FixflowMaintenanceListScreen({super.key, this.clock});

  @override
  State<FixflowMaintenanceListScreen> createState() =>
      _FixflowMaintenanceListScreenState();
}

class _FixflowMaintenanceListScreenState
    extends State<FixflowMaintenanceListScreen> {
  FixflowStatusCatalog _catalog = FixflowStatusCatalog.empty;
  List<FixflowMaintenance> _items = const [];
  bool _openOnly = true;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _catalog = await FixflowServices.status
          .catalog(FixflowConstants.maintenanceEntity);
      final open = _catalog.openCodes;
      final list = await FixflowServices.workRequests.listMaintenances(
        statuses: _openOnly && open.isNotEmpty ? open : null,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _typeLabel(String? type) {
    if (type == null || type.isEmpty) return '';
    return ffT('fixflow.maintenance_type.$type', type);
  }

  @override
  Widget build(BuildContext context) {
    final now = (widget.clock ?? DateTime.now)();
    return Scaffold(
      appBar: AppBar(
        title: Text(ffT('fixflow.mobile.maintenance_title', 'Maintenance plan')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: Text(ffT('fixflow.mobile.filter_open', 'Open')),
                selected: _openOnly,
                onSelected: (v) {
                  setState(() => _openOnly = v);
                  _load();
                },
              ),
            ),
          ),
          Expanded(child: _body(now)),
        ],
      ),
    );
  }

  Widget _body(DateTime now) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.error_outline,
          title: ffT('fixflow.mobile.load_failed', 'Could not load'),
          message: ffT('fixflow.mobile.try_again_hint',
              'Check your connection and try again.'),
          actionLabel: ffT('fixflow.mobile.retry', 'Retry'),
          onAction: _load,
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.build_circle_outlined,
          title: ffT('fixflow.mobile.no_maintenance', 'No maintenance planned'),
          message: ffT('fixflow.mobile.no_maintenance_hint',
              'There is no maintenance for this filter.'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final m = _items[i];
          final theme = Theme.of(context);
          final when = m.scheduledDate ?? m.dueDate;
          final late = when != null &&
              when.isBefore(now) &&
              !_catalog.isFinal(m.status);
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  m.displayCode,
                  _typeLabel(m.maintenanceType),
                  if (when != null) fixflowDate(when),
                ].where((s) => s.isNotEmpty).join(' · '),
                style: late
                    ? theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error)
                    : null,
              ),
              trailing: FixflowStatusChip(status: m.status, catalog: _catalog),
            ),
          );
        },
      ),
    );
  }
}
