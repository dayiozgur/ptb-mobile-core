import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/fixflow/fixflow_models.dart';
import '../../core/fixflow/fixflow_services.dart';
import '../../core/priority/priority_catalog.dart';
import '../../core/priority/priority_model.dart';
import '../../core/priority/priority_service.dart';
import '../widgets/feedback/app_empty_state.dart';
import 'fixflow_common.dart';

/// **İş talepleri** (`/fixflow/work-requests`) — liste + "yeni talep".
/// Durum adları/renkleri `status_definitions` (work_request, FixFlow).
class FixflowWorkRequestListScreen extends StatefulWidget {
  const FixflowWorkRequestListScreen({super.key});

  @override
  State<FixflowWorkRequestListScreen> createState() =>
      _FixflowWorkRequestListScreenState();
}

class _FixflowWorkRequestListScreenState
    extends State<FixflowWorkRequestListScreen> {
  FixflowStatusCatalog _catalog = FixflowStatusCatalog.empty;
  List<FixflowWorkRequest> _items = const [];
  bool _mineOnly = false;
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
          .catalog(FixflowConstants.workRequestEntity);
      final open = _catalog.openCodes;
      final list = await FixflowServices.workRequests.listWorkRequests(
        mineOnly: _mineOnly,
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

  Future<void> _create() async {
    final created = await Navigator.of(context).push<FixflowWorkRequest>(
      MaterialPageRoute(builder: (_) => const FixflowWorkRequestCreateScreen()),
    );
    if (created != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ffT('fixflow.mobile.work_requests_title', 'Work requests')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('fixflow_wr_new'),
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(ffT('fixflow.mobile.new_work_request', 'New request')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(spacing: 8, children: [
              FilterChip(
                label: Text(ffT('fixflow.mobile.filter_open', 'Open')),
                selected: _openOnly,
                onSelected: (v) {
                  setState(() => _openOnly = v);
                  _load();
                },
              ),
              FilterChip(
                label: Text(
                    ffT('fixflow.mobile.filter_created_by_me', 'Created by me')),
                selected: _mineOnly,
                onSelected: (v) {
                  setState(() => _mineOnly = v);
                  _load();
                },
              ),
            ]),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
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
          icon: Icons.inbox_outlined,
          title: ffT('fixflow.mobile.no_work_requests', 'No work requests'),
          message: ffT('fixflow.mobile.no_work_requests_hint',
              'Create a request to report a need.'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final w = _items[i];
          final theme = Theme.of(context);
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(w.subject,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                w.displayCode,
                if (w.priority != null)
                  fixflowPriorityLabel(w.priority!.toLowerCase(), w.priority),
                fixflowDate(w.createdAt),
              ].where((s) => s.isNotEmpty).join(' · ')),
              trailing:
                  FixflowStatusChip(status: w.status, catalog: _catalog),
              titleTextStyle: theme.textTheme.titleSmall,
            ),
          );
        },
      ),
    );
  }
}

/// **Yeni iş talebi** — konu, açıklama, öncelik (`priorities`
/// `vendor IS NULL AND active`). Başlangıç durumu `status_definitions`
/// `is_initial` kodundan; `code` DB trigger'ından.
class FixflowWorkRequestCreateScreen extends StatefulWidget {
  /// Test için öncelik listesi (null → [PriorityService]).
  final List<Priority>? priorities;

  const FixflowWorkRequestCreateScreen({super.key, this.priorities});

  @override
  State<FixflowWorkRequestCreateScreen> createState() =>
      _FixflowWorkRequestCreateScreenState();
}

class _FixflowWorkRequestCreateScreenState
    extends State<FixflowWorkRequestCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  List<Priority> _priorities = const [];
  String? _priorityCode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPriorities();
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadPriorities() async {
    if (widget.priorities != null) {
      setState(() =>
          _priorities = PriorityCatalog(widget.priorities!).platform);
      return;
    }
    if (!sl.isRegistered<PriorityService>()) return;
    try {
      final rows = await sl<PriorityService>().getAll();
      if (mounted) setState(() => _priorities = PriorityCatalog(rows).platform);
    } catch (_) {/* öncelik opsiyonel */}
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      final catalog = await FixflowServices.status
          .catalog(FixflowConstants.workRequestEntity);
      final created = await FixflowServices.workRequests.createWorkRequest(
        subject: _subject.text,
        description: _description.text,
        priorityCode: _priorityCode,
        initialStatus: catalog.initialCode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ffT('fixflow.mobile.work_request_created',
            'Request {code} created.',
            params: {'code': created.displayCode})),
      ));
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ffT('fixflow.mobile.work_request_create_failed',
            'Request could not be created: {error}',
            params: {'error': e})),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ffT('fixflow.mobile.new_work_request', 'New request')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('fixflow_wr_subject'),
              controller: _subject,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: ffT('fixflow.mobile.subject', 'Subject'),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? ffT('fixflow.mobile.subject_required', 'Subject is required.')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('fixflow_wr_description'),
              controller: _description,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: ffT('fixflow.mobile.description', 'Description'),
              ),
            ),
            const SizedBox(height: 12),
            if (_priorities.isNotEmpty)
              DropdownButtonFormField<String>(
                key: const Key('fixflow_wr_priority'),
                initialValue: _priorityCode,
                decoration: InputDecoration(
                  labelText: ffT('fixflow.mobile.priority', 'Priority'),
                ),
                items: _priorities
                    .where((p) => p.code != null)
                    .map((p) => DropdownMenuItem(
                          value: p.code,
                          child: Text(fixflowPriorityLabel(p.code, p.name)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _priorityCode = v),
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('fixflow_wr_save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(ffT('fixflow.mobile.submit', 'Submit')),
            ),
          ],
        ),
      ),
    );
  }
}
