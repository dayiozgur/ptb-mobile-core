import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import '../contacts/contact_detail_screen.dart';
import '../contacts/contacts_service.dart' show Contact;
import '../pipeline/crm_stage_service.dart';
import '../shared/crm_record.dart';
import 'crm_companies_service.dart';

/// CRM **Firma 360** — web `CompanyDetailComponent` paritesi: firmanın
/// fırsatları (`fn_crm_account_360`) → açık / ağırlıklı / kazanılan KPI'ları +
/// fırsat listesi, bağlı kişiler. Tam kayıt (form + aktivite akışı) çekirdek
/// entity detayında ("Kaydı aç").
class CrmCompanyDetailScreen extends StatefulWidget {
  const CrmCompanyDetailScreen({
    super.key,
    required this.companyId,
    this.initialName,
    this.service,
    this.stageService,
  });

  final String companyId;
  final String? initialName;
  final CrmCompaniesService? service;
  final CrmStageService? stageService;

  @override
  State<CrmCompanyDetailScreen> createState() => _CrmCompanyDetailScreenState();
}

class _CrmCompanyDetailScreenState extends State<CrmCompanyDetailScreen> {
  late final CrmCompaniesService _svc =
      widget.service ?? CrmCompaniesService();
  late final CrmStageService _stages =
      widget.stageService ?? CrmStageService();

  bool _loading = true;
  String? _error;
  List<AccountDeal> _deals = const [];
  List<Contact> _contacts = const [];
  Map<String, CrmStage> _dealStages = const {};

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
      final results = await Future.wait([
        _svc.account360(widget.companyId),
        _svc.contacts(widget.companyId),
        _stages.loadStages('deal'),
      ]);
      if (!mounted) return;
      setState(() {
        _deals = results[0] as List<AccountDeal>;
        _contacts = results[1] as List<Contact>;
        _dealStages = {
          for (final s in results[2] as List<CrmStage>) s.code: s,
        };
        _loading = false;
      });
    } catch (e) {
      Logger.error('crm company 360 hata', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openRecord() {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            EntityDetailScreen(typeCode: 'company', id: widget.companyId)));
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.initialName ?? '').trim();
    return AppScaffold(
      title: name.isNotEmpty
          ? name
          : crmT('crm.companies.detail_title', 'Firma 360'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(
          icon: Icons.open_in_new,
          tooltip: crmT('crm.companies.open_record', 'Kaydı aç'),
          onPressed: _openRecord,
        ),
        AppIconButton(icon: Icons.refresh, onPressed: _load),
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
          title: crmT('crm.companies.error_title', 'Firma yüklenemedi'),
          actionLabel: crmT('common.retry', 'Yeniden dene'),
          onAction: _load,
        ),
      );
    }
    final finals = {
      for (final s in _dealStages.values)
        if (s.isFinal) s.code
    };
    final k = AccountKpis.of(_deals, finals);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Padding(
              padding: AppSpacing.cardInsets,
              child: Column(
                children: [
                  _kv(crmT('crm.reports.kpi_open_pipeline', 'Açık Fırsat Değeri'),
                      crmMoney(k.openPipeline)),
                  _kv(crmT('crm.reports.kpi_weighted', 'Ağırlıklı Tahmin'),
                      crmMoney(k.weighted)),
                  _kv(crmT('crm.reports.kpi_won', 'Kazanılan'), crmMoney(k.won)),
                  _kv(crmT('crm.companies.kpi_deals', 'Fırsat'),
                      '${k.dealCount}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _sectionTitle(crmT('crm.companies.col_deal', 'Fırsat')),
          if (_deals.isEmpty)
            AppEmptyState(
              compact: true,
              icon: Icons.inbox_outlined,
              title: crmT('crm.companies.no_deals', 'Bu firmada fırsat yok'),
            )
          else
            for (final d in _deals) _dealTile(d),
          const SizedBox(height: AppSpacing.md),
          _sectionTitle(crmT('crm.companies.contacts_title', 'Kişiler')),
          if (_contacts.isEmpty)
            AppEmptyState(
              compact: true,
              icon: Icons.person_off_outlined,
              title: crmT('crm.companies.no_contacts', 'Kişi yok'),
            )
          else
            for (final c in _contacts) _contactTile(c),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(t, style: AppTypography.headline),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
            child: Text(k,
                style: AppTypography.caption1
                    .copyWith(color: AppColors.secondaryLabel(context))),
          ),
          Text(v, style: AppTypography.subhead),
        ]),
      );

  Widget _dealTile(AccountDeal d) {
    final st = _dealStages[d.status];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        title: Text(d.subject.isNotEmpty ? d.subject : '—',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${crmMoney(d.amount)} · %${d.probability.round()}'),
        trailing: d.status.isEmpty
            ? null
            : AppBadge(
                label: st?.name ?? EntityStatusLabels.humanize(d.status),
                color: st?.color,
                variant: AppBadgeVariant.neutral,
                size: AppBadgeSize.small,
              ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => EntityDetailScreen(typeCode: 'deal', id: d.id))),
      ),
    );
  }

  Widget _contactTile(Contact c) => Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(c.displayName),
          subtitle: [c.title, c.email]
                  .where((s) => (s ?? '').isNotEmpty)
                  .isEmpty
              ? null
              : Text([c.title, c.email]
                  .where((s) => (s ?? '').isNotEmpty)
                  .join(' · ')),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ContactDetailScreen(contactId: c.id))),
        ),
      );
}
