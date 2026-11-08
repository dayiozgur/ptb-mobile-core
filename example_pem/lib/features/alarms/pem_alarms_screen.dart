import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../pem_common.dart';
import '../shared/pem_models.dart';
import '../shared/pem_widgets.dart';
import 'pem_alarms_service.dart';

/// PEM **Enerji alarmları** (`/admin/energy/alarms`) — tetiklenen enerji
/// alarmları (paylaşımlı `alarms`, ENERGY_* kodları: tüketim/EnPI/referans
/// kuralları ve anomali yükseltmeleri), öncelik rengi/etiketi, durum.
/// Salt-okunur: onay/kapama ve kural yönetimi web'de.
class PemAlarmsScreen extends StatefulWidget {
  const PemAlarmsScreen({super.key, this.service, this.title});

  final PemAlarmsService? service;
  final String? title;

  @override
  State<PemAlarmsScreen> createState() => _PemAlarmsScreenState();
}

class _PemAlarmsScreenState extends State<PemAlarmsScreen> {
  late final PemAlarmsService _service = widget.service ?? PemAlarmsService();

  bool _loading = true;
  String? _error;
  List<PemAlarm> _all = const [];
  PemAlarmFilter _filter = PemAlarmFilter.open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _service.list();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      Logger.error('PEM alarms load failed', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title ?? pemT('energy.alarm.title', 'Enerji Alarmları'),
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
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Row(children: [
              ChoiceChip(
                label: Text(
                    '${pemT('status.active', 'Aktif')} (${_all.where((a) => a.isOpen).length})'),
                selected: _filter == PemAlarmFilter.open,
                onSelected: (_) =>
                    setState(() => _filter = PemAlarmFilter.open),
              ),
              const SizedBox(width: AppSpacing.sm),
              ChoiceChip(
                label: Text('${pemT('common.all', 'Tümü')} (${_all.length})'),
                selected: _filter == PemAlarmFilter.all,
                onSelected: (_) => setState(() => _filter = PemAlarmFilter.all),
              ),
            ]),
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
        title: pemT('pem.mobile.alarms_load_error',
            'Enerji alarmları yüklenemedi'),
        onRetry: () => _load(),
      );
    }
    final rows = PemAlarmsService.apply(_all, _filter);
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: PemScrollableEmpty(
          icon: Icons.check_circle_outline,
          title: pemT('energy.alarm.fired_empty', 'Tetiklenen enerji alarmı yok'),
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

  Widget _card(PemAlarm a) {
    final theme = Theme.of(context);
    final pColor = pemHexColor(a.priority?.color) ?? theme.colorScheme.outline;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: pColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if ((a.description ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(a.description!.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (a.priority != null)
                      _chip(a.priority!.label, pColor),
                    _chip(a.statusLabel,
                        a.isOpen ? theme.colorScheme.error : theme.colorScheme.outline),
                    Text(pemDateTime(a.startTime),
                        style: theme.textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}
