import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import '../pipeline/crm_stage_service.dart';
import '../shared/crm_record.dart';
import '../shared/crm_records_service.dart';
import '../shared/crm_stage_change.dart';

/// Potansiyel listesi süzgeci — saf (test edilebilir).
///
/// Web `LeadConvertComponent` terminal potansiyelleri (converted /
/// disqualified) listeden çıkarır; mobil aynı kümeyi SABİT KOD yerine
/// `status_definitions.is_final` ile belirler. [stageCode] verilirse yalnız o
/// aşama; [query] başlık/e-posta/firma/telefon içinde aranır.
List<CrmRecord> filterLeads(
  List<CrmRecord> leads,
  List<CrmStage> stages, {
  String? stageCode,
  String query = '',
}) {
  final finals = {for (final s in stages) if (s.isFinal) s.code};
  final q = query.trim().toLowerCase();
  return leads.where((l) {
    if (finals.contains(l.status)) return false;
    if (stageCode != null && l.status != stageCode) return false;
    if (q.isEmpty) return true;
    final hay = [
      l.leadTitle ?? '',
      l.code ?? '',
      l.metaStr('email'),
      l.metaStr('contact_email'),
      l.metaStr('company'),
      l.metaStr('company_text'),
      l.metaStr('phone'),
      l.metaStr('contact_phone'),
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }).toList();
}

/// CRM **Potansiyeller** (`/crm/leads`) — aktif (terminal-olmayan) potansiyel
/// iş listesi. Karta dokun → çekirdek entity detayı (`lead`, CRM aksiyon
/// çubuğu + skor + aktivite akışı). Durum değişimi izinli geçişlerle
/// `status-transition` EF üzerinden; `converted` hedefi web'deki gibi YALNIZ
/// dönüştürme sihirbazına aittir ve burada sunulmaz.
class CrmLeadsScreen extends StatefulWidget {
  const CrmLeadsScreen({
    super.key,
    this.records,
    this.stageService,
    this.onOpenLead,
  });

  final CrmRecordsService? records;
  final CrmStageService? stageService;
  final void Function(BuildContext context, CrmRecord lead)? onOpenLead;

  static const String entityType = 'lead';

  @override
  State<CrmLeadsScreen> createState() => _CrmLeadsScreenState();
}

class _CrmLeadsScreenState extends State<CrmLeadsScreen> {
  late final CrmRecordsService _records =
      widget.records ?? CrmRecordsService();
  late final CrmStageService _stagesSvc =
      widget.stageService ?? CrmStageService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<CrmRecord> _all = const [];
  List<CrmStage> _stages = const [];
  String? _stage;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _stagesSvc.loadStages(CrmLeadsScreen.entityType),
        _records.list(CrmLeadsScreen.entityType),
      ]);
      if (!mounted) return;
      setState(() {
        _stages = results[0] as List<CrmStage>;
        _all = results[1] as List<CrmRecord>;
        _loading = false;
      });
    } catch (e) {
      Logger.error('crm leads load hata', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v);
    });
  }

  void _open(CrmRecord l) {
    final hook = widget.onOpenLead;
    if (hook != null) return hook(context, l);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => EntityDetailScreen(
                typeCode: CrmLeadsScreen.entityType, id: l.id)))
        .then((_) {
      if (mounted) _load(silent: true);
    });
  }

  void _create() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) =>
                const EntityFormScreen(typeCode: CrmLeadsScreen.entityType)))
        .then((_) {
      if (mounted) _load(silent: true);
    });
  }

  Future<void> _move(CrmRecord l) async {
    final ok = await showCrmStageChange(
      context,
      stageService: _stagesSvc,
      entityType: CrmLeadsScreen.entityType,
      entityId: l.id,
      currentStatus: l.status,
      stages: _stages,
      recordCode: l.code,
    );
    if (ok) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: crmT('crm.leads.title', 'Potansiyeller'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [AppIconButton(icon: Icons.refresh, onPressed: () => _load())],
      floatingActionButton: FloatingActionButton(
        tooltip: crmT('crm.leads.new', 'Yeni Potansiyel'),
        onPressed: _create,
        child: const Icon(Icons.person_add_alt_1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText:
                    crmT('crm.leads.search_placeholder', 'Potansiyel ara...'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (!_loading && _error == null) _stageFilter(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _stageFilter() {
    final open = _stages.where((s) => !s.isFinal).toList();
    if (open.isEmpty) return const SizedBox(height: AppSpacing.sm);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Text(crmT('common.all', 'Tümü')),
              selected: _stage == null,
              onSelected: (_) => setState(() => _stage = null),
            ),
          ),
          for (final s in open)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                key: ValueKey('crm-lead-stage-${s.code}'),
                label: Text(s.name),
                selected: _stage == s.code,
                onSelected: (_) => setState(() => _stage = s.code),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.error_outline,
          title: crmT('crm.leads.load_error', 'Potansiyeller yüklenemedi'),
          actionLabel: crmT('common.retry', 'Yeniden dene'),
          onAction: () => _load(),
        ),
      );
    }
    final rows = filterLeads(_all, _stages, stageCode: _stage, query: _query);
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            AppEmptyState(
              icon: Icons.person_search_outlined,
              title: crmT('crm.leads.no_data', 'Potansiyel bulunamadı'),
            ),
          ],
        ),
      );
    }
    final labels = {for (final s in _stages) s.code: s};
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _card(rows[i], labels),
      ),
    );
  }

  Widget _card(CrmRecord l, Map<String, CrmStage> labels) {
    final st = labels[l.status];
    final company = l.metaStr('company').isNotEmpty
        ? l.metaStr('company')
        : l.metaStr('company_text');
    final title = l.leadTitle ??
        crmT('crm.leads.untitled', '(başlıksız potansiyel)');
    final sub = [
      if (company.isNotEmpty && !title.contains(company)) company,
      l.metaStr('source'),
    ].where((s) => s.isNotEmpty).join(' · ');
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(l),
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.subhead,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (sub.isNotEmpty)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption1.copyWith(
                              color: AppColors.secondaryLabel(context))),
                    if ((l.status ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: AppBadge(
                          label: st?.name ??
                              EntityStatusLabels.humanize(l.status!),
                          color: st?.color,
                          variant: AppBadgeVariant.neutral,
                          size: AppBadgeSize.small,
                        ),
                      ),
                  ],
                ),
              ),
              AppIconButton(
                icon: Icons.swap_horiz,
                tooltip: crmT('crm.stage.change', 'Durum değiştir'),
                onPressed: () => _move(l),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
