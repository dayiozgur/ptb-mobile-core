import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import '../shared/crm_record.dart';
import '../shared/crm_records_service.dart';
import '../shared/crm_stage_change.dart';
import 'crm_stage_service.dart';

/// Fırsatların aşamalara göre gruplanması — saf (test edilebilir).
///
/// Her `status_definitions` aşaması bir grup (sort_order sıralı); tanımı
/// olmayan durumdaki fırsatlar kaybolmasın diye kendi (okunur-kod) grubunda
/// sona eklenir (web deal-pipeline overflow kolonu paritesi).
class PipelineGroups {
  final List<CrmStage> stages;
  final Map<String, List<CrmRecord>> byStage;

  const PipelineGroups(this.stages, this.byStage);

  factory PipelineGroups.build(List<CrmStage> stages, List<CrmRecord> deals) {
    final known = {for (final s in stages) s.code};
    final by = <String, List<CrmRecord>>{for (final s in stages) s.code: []};
    final extra = <CrmStage>[];
    for (final d in deals) {
      final code = (d.status ?? '').isEmpty ? '' : d.status!;
      if (!known.contains(code)) {
        known.add(code);
        extra.add(CrmStage(
          code: code,
          name: code.isEmpty ? '—' : EntityStatusLabels.humanize(code),
          sortOrder: 1 << 30,
        ));
        by[code] = [];
      }
      by[code]!.add(d);
    }
    return PipelineGroups([...stages, ...extra], by);
  }

  /// Açık (final-olmayan) aşamalardaki fırsatlar — web "open pipeline".
  Iterable<CrmRecord> get openDeals => stages
      .where((s) => !s.isFinal)
      .expand((s) => byStage[s.code] ?? const <CrmRecord>[]);
}

/// CRM **Satış Hattı** (`/crm/pipeline`) — web `DealPipelineComponent`'in
/// telefona uygun karşılığı: yatay aşama şeridi (ad + adet, DB renk/etiket) +
/// seçili aşamanın fırsat listesi. Karta dokun → fırsat detayı (çekirdek
/// entity detay + CRM aksiyonları). Aşama değişimi yalnız izinli geçişlerle,
/// `status-transition` EF üzerinden (web ile aynı).
class CrmPipelineScreen extends StatefulWidget {
  const CrmPipelineScreen({
    super.key,
    this.records,
    this.stageService,
    this.onOpenDeal,
  });

  final CrmRecordsService? records;
  final CrmStageService? stageService;

  /// Test/özelleştirme kancası; varsayılan: çekirdek `EntityDetailScreen`.
  final void Function(BuildContext context, CrmRecord deal)? onOpenDeal;

  static const String entityType = 'deal';

  @override
  State<CrmPipelineScreen> createState() => _CrmPipelineScreenState();
}

class _CrmPipelineScreenState extends State<CrmPipelineScreen> {
  late final CrmRecordsService _records =
      widget.records ?? CrmRecordsService();
  late final CrmStageService _stages =
      widget.stageService ?? CrmStageService();

  bool _loading = true;
  String? _error;
  bool _truncated = false;
  PipelineGroups _groups = const PipelineGroups([], {});
  String? _selected;
  RealtimeRefresher? _rt;

  @override
  void initState() {
    super.initState();
    _load();
    // Canlı-yenileme yalnız gerçek backend'de (test enjeksiyonunda kapalı).
    if (widget.records == null) {
      _rt = RealtimeRefresher()
        ..start(
          table: 'form_submissions',
          onChange: () {
            if (mounted) _load(silent: true);
          },
        );
    }
  }

  @override
  void dispose() {
    _rt?.dispose();
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
        _stages.loadStages(CrmPipelineScreen.entityType),
        _records.list(CrmPipelineScreen.entityType),
      ]);
      final stages = results[0] as List<CrmStage>;
      final deals = results[1] as List<CrmRecord>;
      final groups = PipelineGroups.build(stages, deals);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _truncated = CrmRecordsService.isTruncated(deals.length);
        _loading = false;
        final codes = groups.stages.map((s) => s.code).toList();
        if (_selected == null || !codes.contains(_selected)) {
          // İlk dolu aşama; yoksa ilk aşama.
          _selected = groups.stages
                  .where((s) => (groups.byStage[s.code] ?? const []).isNotEmpty)
                  .map((s) => s.code)
                  .firstOrNull ??
              codes.firstOrNull;
        }
      });
    } catch (e) {
      Logger.error('crm pipeline load hata', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _open(CrmRecord d) {
    final hook = widget.onOpenDeal;
    if (hook != null) return hook(context, d);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => EntityDetailScreen(
                typeCode: CrmPipelineScreen.entityType, id: d.id)))
        .then((_) {
      if (mounted) _load(silent: true);
    });
  }

  Future<void> _move(CrmRecord d) async {
    final ok = await showCrmStageChange(
      context,
      stageService: _stages,
      entityType: CrmPipelineScreen.entityType,
      entityId: d.id,
      currentStatus: d.status,
      stages: _groups.stages,
      recordCode: d.code ?? d.dealTitle,
    );
    if (ok) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: crmT('crm.pipeline.title', 'Satış Hattı'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: () => _load()),
      ],
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.error_outline,
          title: crmT('crm.pipeline.error_title', 'Satış hattı yüklenemedi'),
          actionLabel: crmT('crm.pipeline.retry', 'Tekrar dene'),
          onAction: () => _load(),
        ),
      );
    }
    final all = _groups.byStage.values.fold<int>(0, (a, l) => a + l.length);
    if (all == 0) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            AppEmptyState(
              icon: Icons.view_kanban_outlined,
              title: crmT('crm.pipeline.empty_title', 'Henüz fırsat yok'),
              message: crmT('crm.pipeline.empty_message',
                  'Satış hattında görmek için bir fırsat oluşturun.'),
            ),
          ],
        ),
      );
    }
    final deals = _groups.byStage[_selected] ?? const <CrmRecord>[];
    return Column(
      children: [
        _summary(),
        _stageStrip(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: deals.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      AppEmptyState(
                        compact: true,
                        icon: Icons.inbox_outlined,
                        title: crmT('common.no_data', 'Veri yok'),
                      ),
                    ],
                  )
                : ListView.separated(
                    key: const ValueKey('crm-pipeline-deals'),
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                    itemCount: deals.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => _dealCard(deals[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _summary() {
    final open = _groups.openDeals.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: AppCard(
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv(crmT('crm.pipeline.total_value', 'Satış Hattı Değeri'),
                  crmMoneyTotals(crmSumByCurrency(open))),
              const SizedBox(height: 4),
              _kv(crmT('crm.reports.kpi_weighted', 'Ağırlıklı Tahmin'),
                  crmMoneyTotals(crmSumByCurrency(open, weighted: true))),
              if (_truncated) ...[
                const SizedBox(height: 4),
                Text('${CrmRecordsService.pageCap}+',
                    style: AppTypography.caption2
                        .copyWith(color: AppColors.tertiaryLabel(context))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        children: [
          Expanded(
            child: Text(k,
                style: AppTypography.caption1
                    .copyWith(color: AppColors.secondaryLabel(context))),
          ),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.end,
                style: AppTypography.subhead,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );

  Widget _stageStrip() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        children: [
          for (final s in _groups.stages)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                key: ValueKey('crm-stage-${s.code}'),
                avatar: Icon(Icons.circle,
                    size: 10, color: s.color ?? AppColors.primary),
                label: Text(
                    '${s.name} (${(_groups.byStage[s.code] ?? const []).length})'),
                selected: _selected == s.code,
                onSelected: (_) => setState(() => _selected = s.code),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dealCard(CrmRecord d) {
    final amount = d.amount;
    final prob = d.probability;
    final close = d.expectedClose;
    final meta = <String>[
      if (amount != null) crmMoney(amount, d.currency),
      if (prob != null) '%${prob.round()}',
      if (close != null) AppClock.date(close),
    ];
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(d),
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.dealTitle,
                        style: AppTypography.subhead,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (d.companyName.isNotEmpty &&
                        d.companyName != d.dealTitle)
                      Text(d.companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption1.copyWith(
                              color: AppColors.secondaryLabel(context))),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(meta.join(' · '),
                            style: AppTypography.caption1),
                      ),
                  ],
                ),
              ),
              AppIconButton(
                icon: Icons.swap_horiz,
                tooltip: crmT('crm.stage.change', 'Durum değiştir'),
                onPressed: () => _move(d),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
