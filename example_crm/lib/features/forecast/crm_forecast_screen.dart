import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../crm_common.dart';

/// CRM **Satış Tahmini** — web `ForecastBoardComponent` (CRM-07) mobil paritesi.
/// Bir dönem için per-temsilci forecast-vs-quota rollup'ını gösterir (commit /
/// best-case / pipeline / won / attainment %) ve çağıranın kendi tahminini
/// `crm_forecast_snapshots`'a dondurur ("Tahminimi Gönder").
class CrmForecastScreen extends StatefulWidget {
  const CrmForecastScreen({super.key});

  @override
  State<CrmForecastScreen> createState() => _CrmForecastScreenState();
}

class _CrmForecastScreenState extends State<CrmForecastScreen> {
  late final CrmForecastService _svc = CrmForecastService(supabase: sl<SupabaseClient>());
  bool _loading = true;
  bool _submitting = false;
  List<ForecastRow> _rows = const [];
  String _periodType = 'month';
  late DateTime _periodStart = _snap(DateTime.now(), 'month');

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Dönemi tipine göre başlangıca hizala (ay → ayın 1'i, çeyrek → çeyreğin 1. ayı).
  static DateTime _snap(DateTime d, String type) {
    if (type == 'quarter') {
      final qStartMonth = ((d.month - 1) ~/ 3) * 3 + 1;
      return DateTime(d.year, qStartMonth, 1);
    }
    return DateTime(d.year, d.month, 1);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _svc.getRollup(_periodType, _periodStart);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  void _onTypeChanged(String? t) {
    if (t == null || t == _periodType) return;
    setState(() {
      _periodType = t;
      _periodStart = _snap(_periodStart, t);
    });
    _load();
  }

  void _step(int dir) {
    setState(() {
      _periodStart = _periodType == 'quarter'
          ? DateTime(_periodStart.year, _periodStart.month + 3 * dir, 1)
          : DateTime(_periodStart.year, _periodStart.month + dir, 1);
    });
    _load();
  }

  String get _periodLabel {
    if (_periodType == 'quarter') {
      final q = ((_periodStart.month - 1) ~/ 3) + 1;
      return 'Q$q ${_periodStart.year}';
    }
    const months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return '${months[_periodStart.month]} ${_periodStart.year}';
  }

  static String _money(double v) {
    final n = v.round();
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}${buf.toString()} ₺';
  }

  Future<void> _submit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(crmT('crm.forecast.submit', 'Tahminimi Gönder')),
        content: Text(crmT('crm.forecast.submit_confirm',
            '$_periodLabel dönemi için kendi tahminin dondurulacak. Devam?')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: Text(crmT('crm.common.cancel', 'Vazgeç'))),
          TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text(crmT('crm.forecast.submit', 'Gönder'))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _submitting = true);
    final ok = await _svc.submitForecast(_periodType, _periodStart);
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? crmT('crm.forecast.submitted', 'Tahmin gönderildi ✓')
            : crmT('crm.common.action_failed', 'İşlem başarısız'))));
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: crmT('crm.forecast.title', 'Satış Tahmini'),
      onBack: () => context.pop(),
      actions: [AppIconButton(icon: Icons.refresh, onPressed: _load)],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitting ? null : _submit,
        icon: _submitting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_outline),
        label: Text(crmT('crm.forecast.submit', 'Tahminimi Gönder')),
      ),
      child: Column(
        children: [
          _periodBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _rows.isEmpty
                        ? ListView(children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Center(child: Text(crmT('crm.forecast.empty', 'Bu dönem için veri yok.'))),
                            )
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 88),
                            itemCount: _rows.length,
                            itemBuilder: (_, i) => _repCard(_rows[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _periodBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: AppDropdown<String>(
              value: _periodType,
              onChanged: _onTypeChanged,
              items: [
                AppDropdownItem(value: 'month', label: crmT('crm.forecast.month', 'Ay')),
                AppDropdownItem(value: 'quarter', label: crmT('crm.forecast.quarter', 'Çeyrek')),
              ],
            ),
          ),
          const Spacer(),
          IconButton(onPressed: () => _step(-1), icon: const Icon(Icons.chevron_left)),
          Text(_periodLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(onPressed: () => _step(1), icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }

  Widget _repCard(ForecastRow r) {
    final pct = r.attainmentPct.clamp(0, 200).toDouble();
    final barColor = pct >= 100 ? Colors.green : (pct >= 70 ? Colors.orange : Colors.redAccent);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(r.ownerName, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (r.isSubmitted)
                  Chip(
                    label: Text(crmT('crm.forecast.submitted_badge', 'Gönderildi'),
                        style: const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: Colors.green,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.black12,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 4),
            Text('${crmT('crm.forecast.attainment', 'Ulaşım')}: %${pct.toStringAsFixed(0)}  ·  '
                '${crmT('crm.forecast.quota', 'Kota')} ${_money(r.quota)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 4, children: [
              _metric(crmT('crm.forecast.commit', 'Commit'), _money(r.commit)),
              _metric(crmT('crm.forecast.best_case', 'En iyi'), _money(r.bestCase)),
              _metric(crmT('crm.forecast.pipeline', 'Pipeline'), _money(r.pipeline)),
              _metric(crmT('crm.forecast.won', 'Kazanılan'), _money(r.won)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      );
}
