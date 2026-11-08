import 'package:flutter/material.dart';

import '../../core/fixflow/fixflow_models.dart';
import '../../core/fixflow/fixflow_services.dart';
import '../widgets/feedback/app_empty_state.dart';
import 'fixflow_common.dart';
import 'fixflow_ticket_detail_screen.dart';

/// Durum filtresi: açık (is_final=false) / tümü / tek durum kodu.
const String _kOpen = '__open__';
const String _kAll = '__all__';

/// **Biletlerim** — teknisyen bilet listesi (`/fixflow/tickets`).
///
/// Kapsam: bana atanan / ekibim / tümü. Durum filtreleri `status_definitions`
/// (FixFlow platformu) kataloğundan gelir — sabit durum yok; varsayılan
/// "açık" = `is_final = false` kodları. [slaMode] (`/fixflow/sla`): tüm açık
/// biletler `due_date` artan, gecikenler vurgulu.
class FixflowTicketListScreen extends StatefulWidget {
  final FixflowTicketScope initialScope;
  final bool slaMode;

  /// Test için sabit "şimdi" (gecikme hesabı).
  final DateTime Function()? clock;

  const FixflowTicketListScreen({
    super.key,
    this.initialScope = FixflowTicketScope.mine,
    this.slaMode = false,
    this.clock,
  });

  @override
  State<FixflowTicketListScreen> createState() =>
      _FixflowTicketListScreenState();
}

class _FixflowTicketListScreenState extends State<FixflowTicketListScreen> {
  late FixflowTicketScope _scope =
      widget.slaMode ? FixflowTicketScope.all : widget.initialScope;
  String _statusFilter = _kOpen;
  FixflowStatusCatalog _catalog = FixflowStatusCatalog.empty;
  List<FixflowTicket> _tickets = const [];
  bool _loading = true;
  Object? _error;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String>? _statusArg() {
    if (_statusFilter == _kAll) return null;
    if (_statusFilter == _kOpen) {
      final open = _catalog.openCodes;
      return open.isEmpty ? null : open;
    }
    return [_statusFilter];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _catalog = await FixflowServices.status
          .catalog(FixflowConstants.ticketEntity);
      final list = await FixflowServices.tickets.listTickets(
        scope: _scope,
        statuses: _statusArg(),
        orderByDue: widget.slaMode,
      );
      if (!mounted) return;
      setState(() {
        _tickets = list;
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

  Future<void> _open(FixflowTicket t) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FixflowTicketDetailScreen(ticketId: t.id),
    ));
    if (mounted) _load();
  }

  String _scopeLabel(FixflowTicketScope s) {
    switch (s) {
      case FixflowTicketScope.mine:
        return ffT('fixflow.mobile.scope_mine', 'Assigned to me');
      case FixflowTicketScope.team:
        return ffT('fixflow.mobile.scope_team', 'My team');
      case FixflowTicketScope.all:
        return ffT('fixflow.mobile.scope_all', 'All');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.slaMode
        ? ffT('fixflow.mobile.sla_title', 'SLA tracking')
        : ffT('fixflow.mobile.tickets_title', 'My tickets');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            key: const Key('fixflow_tickets_refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.slaMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SegmentedButton<FixflowTicketScope>(
                segments: FixflowTicketScope.values
                    .map((s) => ButtonSegment(
                          value: s,
                          label: Text(_scopeLabel(s),
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                selected: {_scope},
                showSelectedIcon: false,
                onSelectionChanged: (v) {
                  setState(() => _scope = v.first);
                  _load();
                },
              ),
            ),
          if (!widget.slaMode) _statusChips(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _statusChips() {
    final chips = <(String, String)>[
      (_kOpen, ffT('fixflow.mobile.filter_open', 'Open')),
      (_kAll, ffT('fixflow.mobile.filter_all', 'All')),
      ..._catalog.statuses.map((s) => (s.code, s.name)),
    ];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (code, label) = chips[i];
          return ChoiceChip(
            label: Text(label),
            selected: _statusFilter == code,
            onSelected: (_) {
              setState(() => _statusFilter = code);
              _load();
            },
          );
        },
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
    if (_tickets.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.assignment_turned_in_outlined,
          title: ffT('fixflow.mobile.no_tickets', 'No tickets'),
          message: ffT('fixflow.mobile.no_tickets_hint',
              'There are no tickets for this filter.'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _TicketCard(
          ticket: _tickets[i],
          catalog: _catalog,
          now: _now,
          onTap: () => _open(_tickets[i]),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final FixflowTicket ticket;
  final FixflowStatusCatalog catalog;
  final DateTime now;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.catalog,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final theme = Theme.of(context);
    final overdue = !catalog.isFinal(t.status) && t.isOverdueAt(now);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(t.displayCode,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const Spacer(),
                  FixflowStatusChip(status: t.status, catalog: catalog),
                ],
              ),
              const SizedBox(height: 4),
              Text(t.subject,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FixflowPriorityChip(
                    code: t.priorityCode,
                    name: t.priorityName,
                    colorHex: t.priorityColor,
                  ),
                  if (t.locationName != null)
                    _meta(context, Icons.place_outlined, t.locationName!),
                  if (t.dueDate != null)
                    _meta(
                      context,
                      Icons.schedule,
                      overdue
                          ? ffT('fixflow.mobile.overdue_since',
                              'Overdue · {date}',
                              params: {'date': fixflowDate(t.dueDate)})
                          : fixflowDate(t.dueDate),
                      color: overdue ? theme.colorScheme.error : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text,
      {Color? color}) {
    final c = color ?? Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 2),
        Text(text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c)),
      ],
    );
  }
}
