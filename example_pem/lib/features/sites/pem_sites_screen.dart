import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../pem_common.dart';
import '../shared/pem_models.dart';
import '../shared/pem_widgets.dart';
import 'pem_site_detail_screen.dart';
import 'pem_sites_service.dart';

/// Kıyaslama model kalitesi etiketi (`energy.mvsavings.validity.<code>`).
String pemValidityLabel(String? code) {
  final c = (code ?? '').trim();
  if (c.isEmpty) return '—';
  return pemT('energy.mvsavings.validity.$c', EntityStatusLabels.humanize(c));
}

/// PEM **Saha listesi** (`/admin/energy/benchmarking`,
/// `/admin/energy/consumption`) — sahalar + son 12 ayın hava-normalize
/// kıyaslama sırası/tüketimi; karta dokun → saha enerji detayı.
class PemSitesScreen extends StatefulWidget {
  const PemSitesScreen({super.key, this.service, this.title, this.onOpenSite});

  final PemSitesService? service;
  final String? title;
  final void Function(BuildContext context, PemSite site)? onOpenSite;

  @override
  State<PemSitesScreen> createState() => _PemSitesScreenState();
}

class _PemSitesScreenState extends State<PemSitesScreen> {
  late final PemSitesService _service = widget.service ?? PemSitesService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<PemSite> _all = const [];
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
      final list = await _service.listSites();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      Logger.error('PEM sites load failed', e);
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

  void _open(PemSite s) {
    final hook = widget.onOpenSite;
    if (hook != null) return hook(context, s);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PemSiteDetailScreen(site: s, service: _service),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title ?? pemT('pem.mobile.sites_title', 'Sahalar'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          tooltip: pemT('common.refresh', 'Yenile'),
          onPressed: () => _load(),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: pemT('common.search', 'Ara'),
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
      return PemErrorState(
        title: pemT('pem.mobile.sites_load_error', 'Sahalar yüklenemedi'),
        onRetry: () => _load(),
      );
    }
    final rows = PemSitesService.filter(_all, _query);
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: PemScrollableEmpty(
          icon: Icons.location_city_outlined,
          title: _all.isEmpty
              ? pemT('energy.meter.no_sites_title', 'Henüz tesis yok')
              : pemT('common.no_data', 'Veri yok'),
          message: _all.isEmpty
              ? pemT('energy.meter.no_sites_hint',
                  'Enerji verisi girmeye başlamak için önce bir tesis oluşturun.')
              : null,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _card(rows[i]),
      ),
    );
  }

  Widget _card(PemSite s) {
    final theme = Theme.of(context);
    final sub = [s.code ?? '', s.city ?? '']
        .where((v) => v.trim().isNotEmpty)
        .join(' · ');
    return AppCard(
      onTap: () => _open(s),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              s.rank != null ? '#${s.rank}' : '—',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (sub.isNotEmpty)
                  Text(sub, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  s.consumptionKwh != null
                      ? '${pemT('energy.benchmark.col.consumption', 'Tüketim (kWh)')}: '
                          '${pemNum(s.consumptionKwh)}'
                      : pemValidityLabel('no_data'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
