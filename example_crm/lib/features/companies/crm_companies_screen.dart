import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import '../shared/crm_record.dart';
import '../shared/crm_records_service.dart';
import 'crm_companies_service.dart';
import 'crm_company_detail_screen.dart';

/// Sektör kodu → etiket: `crm.companies.sector.<code>` (web ile aynı
/// anahtarlar), yoksa okunur kod.
String crmSectorLabel(String code) {
  if (code.isEmpty) return '';
  return crmT('crm.companies.sector.$code', EntityStatusLabels.humanize(code));
}

/// CRM **Firmalar** (`/crm/companies`) — web `CompanyListComponent` paritesi:
/// entity-engine `company` kayıtları, arama, karta dokun → Firma 360.
class CrmCompaniesScreen extends StatefulWidget {
  const CrmCompaniesScreen({
    super.key,
    this.records,
    this.companies,
    this.onOpenCompany,
  });

  final CrmRecordsService? records;
  final CrmCompaniesService? companies;
  final void Function(BuildContext context, CrmRecord company)? onOpenCompany;

  static const String entityType = 'company';

  @override
  State<CrmCompaniesScreen> createState() => _CrmCompaniesScreenState();
}

class _CrmCompaniesScreenState extends State<CrmCompaniesScreen> {
  late final CrmRecordsService _records =
      widget.records ?? CrmRecordsService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<CrmRecord> _all = const [];
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
      final list = await _records.list(CrmCompaniesScreen.entityType);
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      Logger.error('crm companies load hata', e);
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

  void _open(CrmRecord c) {
    final hook = widget.onOpenCompany;
    if (hook != null) return hook(context, c);
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CrmCompanyDetailScreen(
              companyId: c.id,
              initialName: c.subject,
              service: widget.companies,
            )));
  }

  void _create() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => const EntityFormScreen(
                typeCode: CrmCompaniesScreen.entityType)))
        .then((_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: crmT('nav.crm_companies', 'Firmalar'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [AppIconButton(icon: Icons.refresh, onPressed: () => _load())],
      floatingActionButton: FloatingActionButton(
        tooltip: crmT('crm.companies.new', 'Yeni firma'),
        onPressed: _create,
        child: const Icon(Icons.add_business_outlined),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText:
                    crmT('crm.companies.search_placeholder', 'Firma ara…'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(child: _body()),
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
          title: crmT('crm.companies.load_error', 'Firmalar yüklenemedi'),
          actionLabel: crmT('common.retry', 'Yeniden dene'),
          onAction: () => _load(),
        ),
      );
    }
    final rows = filterCompanies(_all, _query);
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            AppEmptyState(
              icon: Icons.business_outlined,
              title: crmT('crm.companies.no_data', 'Firma yok'),
              message: _all.isEmpty
                  ? crmT('crm.companies.no_data_message',
                      'İlk firmanızı ekleyerek başlayın.')
                  : null,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _card(rows[i]),
      ),
    );
  }

  Widget _card(CrmRecord c) {
    final name = (c.subject ?? '').trim().isNotEmpty
        ? c.subject!.trim()
        : crmT('crm.companies.untitled', '(başlıksız)');
    final sub = [
      c.metaStr('city'),
      crmSectorLabel(c.metaStr('sector')),
    ].where((s) => s.isNotEmpty).join(' · ');
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(c),
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(Icons.business, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTypography.subhead,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (sub.isNotEmpty)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption1.copyWith(
                              color: AppColors.secondaryLabel(context))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
