import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ppm_common.dart';
import '../dashboard/ppm_sprint_screen.dart';

/// PPM **Sprint Yönetimi** — sprint'leri durumuna göre listeler ve yaşam-döngüsü
/// aksiyonlarını (future→**Başlat**, active→**Tamamla**) kurar. Web
/// `PtbSprintService` (start/complete) paritesinin mobil UI'ı; kapanışta
/// biten-olmayan issue'lar servis tarafında backlog'a döner. Aktif-sprint
/// burndown/kapasite ise ayrı `PpmSprintScreen`'de (bu ekran yönetim odaklı).
class PpmSprintsManageScreen extends StatefulWidget {
  const PpmSprintsManageScreen({super.key});

  @override
  State<PpmSprintsManageScreen> createState() => _PpmSprintsManageScreenState();
}

class _PpmSprintsManageScreenState extends State<PpmSprintsManageScreen> {
  late final SupabaseClient _sb = sl<SupabaseClient>();
  late final SprintService _svc = SprintService(supabase: _sb);
  bool _loading = false;
  bool _loadingProjects = true;
  List<Sprint> _sprints = const [];
  List<AppDropdownItem<String>> _projectItems = const [];
  String? _projectId;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  /// Jira-style: sprint tam 1 projeye ait → önce projeyi seç, sonra o projenin
  /// sprint'lerini yükle. Projeler doğrudan RLS-scope'lu sorgulanır (proje kökü).
  Future<void> _loadProjects() async {
    setState(() => _loadingProjects = true);
    try {
      final rows = await _sb
          .from('form_submissions')
          .select('id, subject')
          .inFilter('entity_type', ['project', 'arge_proje'])
          .eq('active', true)
          .order('subject', ascending: true);
      final items = (rows as List)
          .map((r) => AppDropdownItem<String>(
                value: (r as Map)['id'] as String,
                label: (r['subject'] as String?) ?? (r['id'] as String),
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _projectItems = items;
        _loadingProjects = false;
        // Tek proje varsa otomatik seç.
        if (items.length == 1) _projectId = items.first.value;
      });
      if (_projectId != null) await _load();
    } catch (e) {
      Logger.error('loadProjects hata', e);
      if (!mounted) return;
      setState(() => _loadingProjects = false);
    }
  }

  void _onProjectChanged(String? id) {
    setState(() {
      _projectId = id;
      _sprints = const [];
    });
    if (id != null) _load();
  }

  Future<void> _load() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _loading = true);
    final s = await _svc.listSprints(pid);
    if (!mounted) return;
    // active → future → closed sırası (yönetimde en alakalı en üstte).
    int rank(SprintState st) => switch (st) {
          SprintState.active => 0,
          SprintState.future => 1,
          SprintState.closed => 2,
          SprintState.unknown => 3,
        };
    final sorted = [...s]..sort((a, b) => rank(a.state) - rank(b.state));
    setState(() {
      _sprints = sorted;
      _loading = false;
    });
  }

  void _toast(bool ok, String okKey, String okFb) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? ppmT(okKey, okFb)
            : ppmT('ppm.common.action_failed', 'İşlem başarısız'))));
  }

  Future<void> _start(Sprint s) async {
    setState(() => _busyId = s.id);
    final ok = await _svc.startSprint(s.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    _toast(ok, 'ppm.sprint.started', 'Sprint başlatıldı ✓');
    if (ok) await _load();
  }

  Future<void> _complete(Sprint s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(ppmT('ppm.sprint.complete', 'Sprint\'i tamamla')),
        content: Text(ppmT('ppm.sprint.complete_confirm',
            'Sprint kapatılacak; biten olmayan işler backlog\'a dönecek. Devam?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: Text(ppmT('ppm.common.cancel', 'Vazgeç'))),
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: Text(ppmT('ppm.sprint.complete', 'Tamamla'))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busyId = s.id);
    final ok = await _svc.completeSprint(s.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    _toast(ok, 'ppm.sprint.completed', 'Sprint tamamlandı ✓');
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: ppmT('ppm.sprint.manage_title', 'Sprint Yönetimi'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(
          icon: Icons.query_stats,
          tooltip: ppmT('ppm.sprint.capacity_title', 'Kapasite / Burndown'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PpmSprintScreen()),
          ),
        ),
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: AppDropdown<String>(
              label: ppmT('ppm.sprint.project', 'Proje'),
              placeholder: ppmT('ppm.sprint.select_project', 'Bir proje seçin…'),
              prefixIcon: Icons.folder_outlined,
              items: _projectItems,
              value: _projectId,
              onChanged: _onProjectChanged,
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loadingProjects || _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_projectId == null) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
              child: Text(ppmT('ppm.sprint.pick_project_hint',
                  'Sprint\'leri görüntülemek için bir proje seçin.'))),
        )
      ]);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: _sprints.isEmpty
          ? ListView(children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                    child: Text(ppmT('ppm.sprint.empty', 'Sprint yok.'))),
              )
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: _sprints.length,
              itemBuilder: (_, i) => _sprintCard(_sprints[i]),
            ),
    );
  }

  Widget _sprintCard(Sprint s) {
    final busy = _busyId == s.id;
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: ListTile(
        title: Text(s.name),
        subtitle: (s.goal != null && s.goal!.isNotEmpty)
            ? Text(s.goal!, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        leading: _stateChip(s.state),
        trailing: busy
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : _actionFor(s),
      ),
    );
  }

  Widget _stateChip(SprintState st) {
    final (label, color) = switch (st) {
      SprintState.active => (ppmT('ppm.sprint.state_active', 'Aktif'), Colors.green),
      SprintState.future => (ppmT('ppm.sprint.state_future', 'Planlı'), Colors.blueGrey),
      SprintState.closed => (ppmT('ppm.sprint.state_closed', 'Kapalı'), Colors.grey),
      SprintState.unknown => ('—', Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget? _actionFor(Sprint s) => switch (s.state) {
        SprintState.future => TextButton(
            onPressed: () => _start(s),
            child: Text(ppmT('ppm.sprint.start', 'Başlat'))),
        SprintState.active => TextButton(
            onPressed: () => _complete(s),
            child: Text(ppmT('ppm.sprint.complete', 'Tamamla'))),
        _ => null,
      };
}
