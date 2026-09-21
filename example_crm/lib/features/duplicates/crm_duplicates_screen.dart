import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../crm_common.dart';

/// CRM **Yinelenen Kayıtlar** — web `DuplicatesComponent` mobil paritesi.
/// Aday çiftleri (kişi/firma) iki-taraf yan-yana gösterir; kullanıcı hangi
/// kaydın kalacağını seçer ("A'yı tut" / "B'yi tut"), diğeri sunucuda birleşir
/// (`fn_crm_merge_*`, survivor+duplicate — alan-seviye conflict-UI yok).
class CrmDuplicatesScreen extends StatefulWidget {
  const CrmDuplicatesScreen({super.key});

  @override
  State<CrmDuplicatesScreen> createState() => _CrmDuplicatesScreenState();
}

class _CrmDuplicatesScreenState extends State<CrmDuplicatesScreen> {
  late final CrmDuplicateService _svc = CrmDuplicateService(supabase: sl<SupabaseClient>());
  DupKind _kind = DupKind.contact;
  bool _loading = true;
  String? _busyPair;
  List<DuplicatePair> _pairs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pairs = _kind == DupKind.company
        ? await _svc.findCompanyDuplicates()
        : await _svc.findContactDuplicates();
    if (!mounted) return;
    setState(() {
      _pairs = pairs;
      _loading = false;
    });
  }

  void _switchKind(DupKind k) {
    if (k == _kind) return;
    setState(() {
      _kind = k;
      _pairs = const [];
    });
    _load();
  }

  Future<void> _merge(DuplicatePair pair, {required bool keepA}) async {
    final survivor = keepA ? pair.aId : pair.bId;
    final duplicate = keepA ? pair.bId : pair.aId;
    final keptName = keepA ? pair.aTitle : pair.bTitle;
    final goneName = keepA ? pair.bTitle : pair.aTitle;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(crmT('crm.dup.merge', 'Birleştir')),
        content: Text(crmT('crm.dup.merge_confirm',
            '"$goneName" → "$keptName" içine birleşecek. Bu geri alınamaz. Devam?')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: Text(crmT('crm.common.cancel', 'Vazgeç'))),
          TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text(crmT('crm.dup.merge', 'Birleştir'))),
        ],
      ),
    );
    if (confirm != true) return;
    final pairKey = '${pair.aId}_${pair.bId}';
    setState(() => _busyPair = pairKey);
    final ok = await _svc.merge(_kind, survivor, duplicate);
    if (!mounted) return;
    setState(() {
      _busyPair = null;
      if (ok) _pairs = _pairs.where((p) => '${p.aId}_${p.bId}' != pairKey).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? crmT('crm.dup.merged', 'Kayıtlar birleştirildi ✓')
            : crmT('crm.common.action_failed', 'İşlem başarısız'))));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: crmT('crm.dup.title', 'Yinelenen Kayıtlar'),
      onBack: () => context.pop(),
      actions: [AppIconButton(icon: Icons.refresh, onPressed: _load)],
      child: Column(
        children: [
          _kindToggle(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _pairs.isEmpty
                        ? ListView(children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Center(child: Text(crmT('crm.dup.empty', 'Yinelenen kayıt bulunamadı 🎉'))),
                            )
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            itemCount: _pairs.length,
                            itemBuilder: (_, i) => _pairCard(_pairs[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kindToggle() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: SegmentedButton<DupKind>(
        segments: [
          ButtonSegment(value: DupKind.contact, label: Text(crmT('crm.dup.contacts', 'Kişiler')), icon: const Icon(Icons.person_outline)),
          ButtonSegment(value: DupKind.company, label: Text(crmT('crm.dup.companies', 'Firmalar')), icon: const Icon(Icons.business_outlined)),
        ],
        selected: {_kind},
        onSelectionChanged: (s) => _switchKind(s.first),
      ),
    );
  }

  Widget _pairCard(DuplicatePair p) {
    final busy = _busyPair == '${p.aId}_${p.bId}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (p.reason != null && p.reason!.isNotEmpty)
                Chip(
                  label: Text(p.reason!, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              const Spacer(),
              Text('%${(p.confidence.clamp(0, 100)).toStringAsFixed(0)} ${crmT('crm.dup.match', 'eşleşme')}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _side(p.aTitle, p.aSubtitle)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('↔', style: TextStyle(color: Colors.black38))),
              Expanded(child: _side(p.bTitle, p.bSubtitle)),
            ]),
            const SizedBox(height: 8),
            if (busy)
              const Center(child: Padding(padding: EdgeInsets.all(6), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
            else
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _merge(p, keepA: true), child: Text(crmT('crm.dup.keep_a', 'A\'yı tut')))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _merge(p, keepA: false), child: Text(crmT('crm.dup.keep_b', 'B\'yi tut')))),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _side(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      );
}
