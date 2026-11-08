import 'package:flutter/material.dart';

import '../../core/fixflow/fixflow_models.dart';
import '../../core/fixflow/fixflow_services.dart';
import '../shell/workflow/approvals_inbox_screen.dart';
import 'fixflow_common.dart';
import 'fixflow_maintenance_list_screen.dart';
import 'fixflow_ticket_list_screen.dart';
import 'fixflow_work_request_screens.dart';

/// **FixFlow pano** (`/fixflow`) — teknisyen özet sayaçları + hızlı geçiş.
/// "Açık" = ilgili entity tipinin `is_final = false` durum kodları
/// (`status_definitions`, sabit kod yok).
class FixflowDashboardScreen extends StatefulWidget {
  final DateTime Function()? clock;

  const FixflowDashboardScreen({super.key, this.clock});

  @override
  State<FixflowDashboardScreen> createState() => _FixflowDashboardScreenState();
}

class _FixflowDashboardScreenState extends State<FixflowDashboardScreen> {
  FixflowDashboardCounts _counts = const FixflowDashboardCounts();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = (widget.clock ?? DateTime.now)();
    final status = FixflowServices.status;
    final tickets = FixflowServices.tickets;
    final wr = FixflowServices.workRequests;
    try {
      final cats = await Future.wait([
        status.catalog(FixflowConstants.ticketEntity),
        status.catalog(FixflowConstants.workRequestEntity),
        status.catalog(FixflowConstants.maintenanceEntity),
      ]);
      final openTk = cats[0].openCodes;
      final counts = await Future.wait([
        tickets.countTickets(scope: FixflowTicketScope.mine, statuses: openTk),
        tickets.countTickets(scope: FixflowTicketScope.team, statuses: openTk),
        tickets.countTickets(
            scope: FixflowTicketScope.mine, statuses: openTk, dueBefore: now),
        wr.countOpen('work_requests', cats[1].openCodes),
        wr.countOpen('maintenances', cats[2].openCodes),
      ]);
      if (!mounted) return;
      setState(() {
        _counts = FixflowDashboardCounts(
          myOpenTickets: counts[0],
          teamOpenTickets: counts[1],
          overdueTickets: counts[2],
          openWorkRequests: counts[3],
          upcomingMaintenance: counts[4],
        );
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _push(Widget w) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _counts;
    final tiles = <_Tile>[
      _Tile(
        Icons.assignment_ind_outlined,
        ffT('fixflow.mobile.kpi_my_open', 'My open tickets'),
        c.myOpenTickets,
        () => _push(const FixflowTicketListScreen()),
      ),
      _Tile(
        Icons.groups_outlined,
        ffT('fixflow.mobile.kpi_team_open', 'Team open tickets'),
        c.teamOpenTickets,
        () => _push(const FixflowTicketListScreen(
            initialScope: FixflowTicketScope.team)),
      ),
      _Tile(
        Icons.alarm_outlined,
        ffT('fixflow.mobile.kpi_overdue', 'My overdue tickets'),
        c.overdueTickets,
        () => _push(const FixflowTicketListScreen(slaMode: true)),
        alert: c.overdueTickets > 0,
      ),
      _Tile(
        Icons.assignment_outlined,
        ffT('fixflow.mobile.kpi_open_work_requests', 'Open work requests'),
        c.openWorkRequests,
        () => _push(const FixflowWorkRequestListScreen()),
      ),
      _Tile(
        Icons.build_outlined,
        ffT('fixflow.mobile.kpi_open_maintenance', 'Open maintenance'),
        c.upcomingMaintenance,
        () => _push(const FixflowMaintenanceListScreen()),
      ),
      _Tile(
        Icons.fact_check_outlined,
        ffT('fixflow.mobile.approvals', 'Approvals'),
        null,
        () => _push(const ApprovalsInboxScreen()),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(ffT('fixflow.mobile.dashboard_title', 'FixFlow')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.4,
          children: tiles
              .map((t) => _TileCard(tile: t, loading: _loading))
              .toList(),
        ),
      ),
    );
  }
}

class _Tile {
  final IconData icon;
  final String label;
  final int? value;
  final VoidCallback onTap;
  final bool alert;

  _Tile(this.icon, this.label, this.value, this.onTap, {this.alert = false});
}

class _TileCard extends StatelessWidget {
  final _Tile tile;
  final bool loading;

  const _TileCard({required this.tile, required this.loading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tile.alert ? theme.colorScheme.error : theme.colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(tile.icon, color: color),
              if (tile.value != null)
                Text(loading ? '…' : '${tile.value}',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w600)),
              Text(tile.label,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
