import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';

/// CRM **Takvim / Ajanda** — yaklaşan aktiviteler ve sonraki adımlar
/// (`fn_crm_calendar`). Tarihe göre gruplu; "Benimkiler / Tümü" filtreli.
/// Satıra dokununca ilgili kayda (entity-engine) gider.
class CrmAgendaScreen extends StatefulWidget {
  const CrmAgendaScreen({super.key});

  @override
  State<CrmAgendaScreen> createState() => _CrmAgendaScreenState();
}

class _CrmAgendaScreenState extends State<CrmAgendaScreen> {
  final _svc = AggregateService();
  bool _mineOnly = true;
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Bugünün başından +45 güne kadar (yaklaşan ajanda).
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 45));
    try {
      final rows = await _svc.rows('fn_crm_calendar', params: {
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
        'p_mine': _mineOnly,
      });
      rows.sort((a, b) => (a['event_date']?.toString() ?? '')
          .compareTo(b['event_date']?.toString() ?? ''));
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: crmT('crm.agenda.title', 'Takvim'),
      onBack: () => context.pop(),
      actions: [AppIconButton(icon: Icons.refresh, onPressed: _load)],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: true,
                    label: Text(crmT('crm.common.mine', 'Benimkiler'))),
                ButtonSegment(
                    value: false, label: Text(crmT('crm.common.all', 'Tümü'))),
              ],
              selected: {_mineOnly},
              onSelectionChanged: (s) {
                setState(() => _mineOnly = s.first);
                _load();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(
            child: AppEmptyState(
                icon: Icons.event_available_outlined,
                title: crmT('crm.agenda.empty', 'Yaklaşan etkinlik yok')),
          ),
        ],
      );
    }

    // Tarihe göre grupla (gün başlığı + kartlar).
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in _rows) {
      final d = DateTime.tryParse(r['event_date']?.toString() ?? '');
      final key = d != null ? AppClock.dayLabel(d) : '—';
      groups.putIfAbsent(key, () => []).add(r);
    }

    final children = <Widget>[];
    groups.forEach((day, items) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
        child: Text(day,
            style: AppTypography.footnote.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryLabel(context))),
      ));
      for (final r in items) {
        children.add(_eventCard(r));
      }
    });

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: children,
    );
  }

  Widget _eventCard(Map<String, dynamic> r) {
    final subject = r['subject']?.toString() ?? '—';
    final kind = r['event_kind']?.toString();
    final status = r['status']?.toString();
    final related = r['related_name']?.toString();
    final owner = r['owner_name']?.toString();
    final type = r['entity_type']?.toString();
    final id = r['entity_id']?.toString();
    final d = DateTime.tryParse(r['event_date']?.toString() ?? '');
    final time = d != null ? AppClock.hm(d) : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: AppCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: (type != null && id != null)
              ? () => context.push('/entities/$type/$id')
              : null,
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time,
                        style: AppTypography.caption1.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    if (kind != null && kind.isNotEmpty)
                      Text(kind,
                          style: AppTypography.caption2.copyWith(
                              color: AppColors.tertiaryLabel(context))),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject,
                          style: AppTypography.subhead,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if ([related, owner]
                          .any((s) => (s ?? '').isNotEmpty)) ...[
                        const SizedBox(height: 2),
                        Text(
                          [related, owner]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: AppTypography.caption1.copyWith(
                              color: AppColors.secondaryLabel(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (status != null && status.isNotEmpty)
                  AppBadge(
                      label: status,
                      variant: AppBadgeVariant.info,
                      size: AppBadgeSize.small),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
