import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/entity/entity_config_service.dart';
import '../../../core/entity/entity_data_service.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/ppm/planner_link_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/logger.dart';
import '../../widgets/feedback/app_loading_indicator.dart';
import '../../widgets/navigation/app_scaffold.dart';

/// **Mobile "New Project" wizard** — the mobile parity of the web project-creation wizard.
/// Step 1: name + methodology (Scrum/Kanban, stored in metadata). Step 2: Microsoft Planner
/// (off / auto-create a new plan / link an existing plan). On finish it creates the project via the
/// form-submit Edge Function, patches subject + methodology, and — when chosen — provisions/links a
/// Planner plan and kicks a first sync. Registered on example_ppm at /entities/project/create.
/// (Team assignment is a web-only step for now — mobile has no project-members surface yet.)
class ProjectWizardScreen extends StatefulWidget {
  final String entityType;
  const ProjectWizardScreen({super.key, this.entityType = 'project'});

  @override
  State<ProjectWizardScreen> createState() => _ProjectWizardScreenState();
}

class _ProjectWizardScreenState extends State<ProjectWizardScreen> {
  PlannerLinkService get _planner => sl<PlannerLinkService>();
  SupabaseClient get _sb => sl<SupabaseClient>();

  static String _t(String key, String fallback) {
    final v = sl<LocalizationService>().translate(key);
    return v == key ? fallback : v;
  }

  int _step = 0; // 0 basics, 1 planner
  bool _busy = false;

  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _methodology = 'scrum';

  bool _loadingPlanner = false;
  bool _connected = false;
  List<PlannerPlan> _plans = const [];
  String _plannerMode = 'off'; // off | create | existing
  String? _selectedPlanId;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  bool get _canNext => _name.text.trim().length >= 2;
  bool get _canCreate => _plannerMode != 'existing' || _selectedPlanId != null;

  Future<void> _goPlanner() async {
    setState(() { _step = 1; _loadingPlanner = true; });
    final conn = await _planner.getConnection();
    final connected = conn != null;
    final plans = connected ? await _planner.listPlans() : const <PlannerPlan>[];
    if (!mounted) return;
    setState(() { _connected = connected; _plans = plans; _loadingPlanner = false; });
  }

  Future<void> _create() async {
    if (_busy || !_canCreate) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    try {
      // 1) resolve the project form template + create via the form-submit EF
      final cfg = await sl<EntityConfigService>().getByCode(widget.entityType);
      final templateId = cfg?.defaultFormTemplateId;
      if (templateId == null) {
        _snack(_t('ppm.wizard.create_failed', 'Proje oluşturulamadı'), isError: true);
        setState(() => _busy = false);
        return;
      }
      final res = await sl<EntityDataService>().submitEntity(
        templateId: templateId,
        values: <String, dynamic>{'subject': name},
        entityType: widget.entityType,
      );
      final projectId = (res['submissionId'] ?? res['id'] ?? res['entityId']) as String?;
      if (projectId == null) {
        _snack(_t('ppm.wizard.create_failed', 'Proje oluşturulamadı'), isError: true);
        setState(() => _busy = false);
        return;
      }

      // 2) stamp subject + methodology (tenant-scoped RLS update)
      try {
        await _sb.from('form_submissions').update(<String, dynamic>{
          'subject': name,
          'metadata': <String, dynamic>{
            'methodology': _methodology,
            'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          },
        }).eq('id', projectId);
      } catch (e) {
        Logger.error('[wizard] metadata patch failed', e);
      }

      // 3) Planner
      if (_plannerMode != 'off') {
        final conn = await _planner.getConnection();
        PlannerPlan? plan;
        if (_plannerMode == 'create') {
          plan = await _planner.createPlan(name);
          if (plan == null && mounted) {
            _snack(_t('ppm.wizard.planner_create_failed', 'Planner planı oluşturulamadı'), isError: true);
          }
        } else {
          for (final p in _plans) {
            if (p.id == _selectedPlanId) { plan = p; break; }
          }
        }
        if (plan != null) {
          final link = await _planner.link(
            projectEntityId: projectId, plan: plan, bucketBy: 'status', connectionId: conn?.id,
          );
          if (link != null) _planner.syncNow(); // fire-and-forget first sync
        }
      }

      if (!mounted) return;
      _snack(_t('ppm.wizard.created', 'Proje oluşturuldu'));
      context.go('/entities/project/$projectId');
    } catch (e) {
      Logger.error('[wizard] create failed', e);
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(_t('ppm.wizard.create_failed', 'Proje oluşturulamadı'), isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _t('ppm.wizard.title', 'Yeni Proje'),
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepBar(),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: SingleChildScrollView(child: _step == 0 ? _basics() : _plannerStep())),
          _footer(),
        ],
      ),
    );
  }

  Widget _stepBar() {
    Widget dot(int i, String label) {
      final active = _step == i, done = _step > i;
      return Expanded(
        child: Row(children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: done ? Colors.green.shade600 : (active ? AppColors.primary : AppColors.tertiaryLabel(context)),
            child: done
                ? const Icon(Icons.check, size: 15, color: Colors.white)
                : Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: AppTypography.caption1, overflow: TextOverflow.ellipsis)),
        ]),
      );
    }

    return Row(children: [
      dot(0, _t('ppm.wizard.step_basics', 'Temel Bilgiler')),
      const SizedBox(width: 8),
      dot(1, _t('ppm.wizard.step_planner', 'Planner')),
    ]);
  }

  Widget _basics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_t('ppm.wizard.name', 'Proje adı')} *', style: AppTypography.caption1),
        const SizedBox(height: 4),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true, border: const OutlineInputBorder(),
            hintText: _t('ppm.wizard.name_ph', 'ör. Mobil Uygulama Yenileme'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(_t('ppm.wizard.description', 'Açıklama'), style: AppTypography.caption1),
        const SizedBox(height: 4),
        TextField(
          controller: _desc, maxLines: 2,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(_t('ppm.wizard.methodology', 'Metodoloji'), style: AppTypography.caption1),
        const SizedBox(height: 6),
        Row(children: [
          _methodCard('scrum', Icons.autorenew, _t('ppm.wizard.scrum', 'Scrum'), _t('ppm.wizard.scrum_desc', 'Sprint, backlog, hız')),
          const SizedBox(width: 10),
          _methodCard('kanban', Icons.view_kanban_outlined, _t('ppm.wizard.kanban', 'Kanban'), _t('ppm.wizard.kanban_desc', 'Sürekli akış, WIP')),
        ]),
      ],
    );
  }

  Widget _methodCard(String value, IconData icon, String title, String desc) {
    final sel = _methodology == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _methodology = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? AppColors.primary : AppColors.separator(context), width: sel ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(height: 4),
              Text(title, style: AppTypography.withWeight(AppTypography.body, FontWeight.w600)),
              Text(desc, style: AppTypography.caption2.copyWith(color: AppColors.secondaryLabel(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plannerStep() {
    if (_loadingPlanner) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: AppLoadingIndicator()));
    }
    if (!_connected) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          _t('ppm.wizard.planner_not_connected', 'Planner ile eşitlemek için Microsoft hesabınızı bağlayın.'),
          style: AppTypography.footnote.copyWith(color: AppColors.tertiaryLabel(context)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _radioRow('off', _t('ppm.wizard.planner_off', 'Planner senkronu yok'), true),
        _radioRow('create', _t('ppm.wizard.planner_create', 'Yeni Planner planı oluştur'), true),
        _radioRow('existing', _t('ppm.wizard.planner_existing', 'Mevcut planı bağla'), _plans.isNotEmpty),
        if (_plannerMode == 'existing')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedPlanId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true, border: const OutlineInputBorder(),
                labelText: _t('ppm.planner.pick_plan', 'Planner planı'),
              ),
              items: [
                for (final p in _plans)
                  DropdownMenuItem(value: p.id, child: Text(p.title, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _selectedPlanId = v),
            ),
          ),
        if (_plans.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_t('ppm.wizard.planner_no_existing', 'Mevcut plan bulunamadı.'),
                style: AppTypography.caption1.copyWith(color: AppColors.tertiaryLabel(context))),
          ),
      ],
    );
  }

  Widget _radioRow(String value, String label, bool enabled) {
    final sel = _plannerMode == value;
    return InkWell(
      onTap: enabled ? () => setState(() => _plannerMode = value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20, color: enabled ? (sel ? AppColors.primary : AppColors.secondaryLabel(context)) : AppColors.tertiaryLabel(context)),
          const SizedBox(width: 10),
          Expanded(child: Text(label,
              style: AppTypography.body.copyWith(color: enabled ? null : AppColors.tertiaryLabel(context)))),
        ]),
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => setState(() => _step = 0),
              icon: const Icon(Icons.chevron_left, size: 18),
              label: Text(_t('ppm.wizard.back', 'Geri')),
            ),
          const Spacer(),
          if (_step == 0)
            FilledButton.icon(
              onPressed: _canNext ? _goPlanner : null,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: Text(_t('ppm.wizard.next', 'İleri')),
            )
          else
            FilledButton.icon(
              onPressed: (_busy || !_canCreate) ? null : _create,
              icon: _busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check, size: 18),
              label: Text(_busy ? _t('ppm.wizard.creating', 'Oluşturuluyor…') : _t('ppm.wizard.create', 'Projeyi oluştur')),
            ),
        ],
      ),
    );
  }
}
