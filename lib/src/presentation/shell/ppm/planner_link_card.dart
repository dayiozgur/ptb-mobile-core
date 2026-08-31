import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/ppm/planner_link_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/url_actions.dart';
import '../../widgets/cards/app_card.dart';
import '../../widgets/feedback/app_loading_indicator.dart';

/// **Microsoft Planner card for a PPM project** — the mobile parity of the web project-workspace
/// "Microsoft Planner" tab. Shows whether the project is linked to a Planner plan, lets the user
/// link (plan picker) / unlink, opens the plan in the browser, and triggers an on-demand sync
/// (push tasks → Planner, pull completion → PPM). Mounted on the project entity-detail via
/// `EntityDetailExtensions.registerSections('project', …)`. Link CRUD is tenant-scoped RLS; plan
/// listing + sync flow through the graph-proxy / ppm-planner-sync Edge Functions.
class PlannerLinkCard extends StatefulWidget {
  final String projectEntityId;
  const PlannerLinkCard({super.key, required this.projectEntityId});

  @override
  State<PlannerLinkCard> createState() => _PlannerLinkCardState();
}

class _PlannerLinkCardState extends State<PlannerLinkCard> {
  PlannerLinkService get _svc => sl<PlannerLinkService>();

  bool _loading = true;
  bool _busy = false;
  bool _connected = false;
  PlannerLink? _link;
  List<PlannerPlan> _plans = const [];
  String? _selectedPlanId;
  String _bucketBy = 'status';
  String? _lastSynced;
  PlannerSyncResult? _lastResult;

  static String _t(String key, String fallback) {
    final v = sl<LocalizationService>().translate(key);
    return v == key ? fallback : v;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final conn = await _svc.getConnection();
    final connected = conn != null;
    PlannerLink? link;
    List<PlannerPlan> plans = const [];
    String? lastSynced;
    if (connected) {
      link = await _svc.getLink(widget.projectEntityId);
      if (link != null) {
        lastSynced = await _svc.getLastSyncedAt();
      } else {
        plans = await _svc.listPlans();
      }
    }
    if (!mounted) return;
    setState(() {
      _connected = connected;
      _link = link;
      _plans = plans;
      _lastSynced = lastSynced;
      _loading = false;
    });
  }

  Future<void> _doLink() async {
    PlannerPlan? plan;
    for (final p in _plans) {
      if (p.id == _selectedPlanId) { plan = p; break; }
    }
    if (plan == null) return;
    setState(() => _busy = true);
    final conn = await _svc.getConnection();
    final created = await _svc.link(
      projectEntityId: widget.projectEntityId,
      plan: plan,
      bucketBy: _bucketBy,
      connectionId: conn?.id,
    );
    if (!mounted) return;
    if (created != null) {
      setState(() {
        _link = created;
        _lastSynced = null;
      });
      await _sync(); // fill the plan immediately
    } else {
      setState(() => _busy = false);
      _snack(_t('ppm.planner.toast_link_failed', 'Plan bağlanamadı'), isError: true);
    }
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    final res = await _svc.syncNow();
    final last = await _svc.getLastSyncedAt();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResult = res;
      _lastSynced = last;
    });
    _snack(res != null
        ? _t('ppm.planner.toast_synced', 'Planner senkronizasyonu tamamlandı')
        : _t('ppm.planner.toast_sync_failed', 'Planner senkronizasyonu başarısız'),
        isError: res == null);
  }

  Future<void> _unlink() async {
    final link = _link;
    if (link == null) return;
    setState(() => _busy = true);
    final ok = await _svc.unlink(link.id);
    if (!mounted) return;
    if (ok) {
      final plans = await _svc.listPlans();
      if (!mounted) return;
      setState(() {
        _link = null;
        _lastResult = null;
        _plans = plans;
        _busy = false;
      });
      _snack(_t('ppm.planner.toast_unlinked', 'Planner bağlantısı kaldırıldı'));
    } else {
      setState(() => _busy = false);
      _snack(_t('ppm.planner.toast_unlink_failed', 'Bağlantı kaldırılamadı'), isError: true);
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
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rtl, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(_t('ppm.planner.title', 'Microsoft Planner'), style: AppTypography.subhead),
              ],
            ),
            const SizedBox(height: 4),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: AppLoadingIndicator()))
            else if (!_connected)
              _hint(_t('ppm.planner.not_connected', 'Bu projeyi Planner\'a bağlamak için Microsoft hesabınızı bağlayın.'))
            else if (_link == null)
              _picker()
            else
              _linked(_link!),
          ],
        ),
      ),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: AppTypography.footnote.copyWith(color: AppColors.tertiaryLabel(context))),
      );

  Widget _picker() {
    if (_plans.isEmpty) {
      return _hint(_t('ppm.planner.no_plans',
          'Hesabınızda Planner planı bulunamadı. Önce Planner\'da bir plan oluşturun.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedPlanId,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            labelText: _t('ppm.planner.pick_plan', 'Planner planı'),
          ),
          hint: Text(_t('ppm.planner.pick_plan_placeholder', 'Bir plan seçin…')),
          items: [
            for (final p in _plans)
              DropdownMenuItem(value: p.id, child: Text(p.title, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _busy ? null : (v) => setState(() => _selectedPlanId = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _bucketBy,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            labelText: _t('ppm.planner.bucket_by', 'Grupla'),
          ),
          items: [
            DropdownMenuItem(value: 'status', child: Text(_t('ppm.planner.bucket_status', 'Duruma göre'))),
            DropdownMenuItem(value: 'sprint', child: Text(_t('ppm.planner.bucket_sprint', 'Sprint\'e göre'))),
          ],
          onChanged: _busy ? null : (v) => setState(() => _bucketBy = v ?? 'status'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: (_busy || _selectedPlanId == null) ? null : _doLink,
            icon: _busy
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.link, size: 18),
            label: Text(_t('ppm.planner.link', 'Planı bağla')),
          ),
        ),
      ],
    );
  }

  Widget _linked(PlannerLink link) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.check_circle, size: 15, color: Colors.green.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(link.planTitle ?? link.planId,
                  style: AppTypography.withWeight(AppTypography.body, FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _lastSynced != null
              ? '${_t('ppm.planner.last_synced', 'Son senkron')}: ${_fmt(_lastSynced!)}'
              : _t('ppm.planner.never_synced', 'Henüz senkronize edilmedi'),
          style: AppTypography.caption1.copyWith(color: AppColors.tertiaryLabel(context)),
        ),
        if (_lastResult != null) ...[
          const SizedBox(height: 4),
          Text(
            '${_lastResult!.pushed} ↑ · ${_lastResult!.pulled} ↓ · ${_lastResult!.errors} ✕',
            style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context)),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => UrlActions.openUrl(_svc.plannerUrl(link.planId)),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(_t('ppm.planner.open_in_planner', 'Planner\'da Aç')),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _sync,
              icon: _busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync, size: 18),
              label: Text(_busy
                  ? _t('ppm.planner.syncing', 'Senkronize ediliyor…')
                  : _t('ppm.planner.sync_now', 'Şimdi Senkronize Et')),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _unlink,
              icon: Icon(Icons.link_off, size: 16, color: Colors.red.shade600),
              label: Text(_t('ppm.planner.unlink', 'Bağlantıyı Kaldır'),
                  style: TextStyle(color: Colors.red.shade600)),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
  }
}
