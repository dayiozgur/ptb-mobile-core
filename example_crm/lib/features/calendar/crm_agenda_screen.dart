import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';

/// One agenda entry, normalized from either the CRM calendar (`fn_crm_calendar`)
/// or the connected Microsoft (Outlook) calendar (`/me/calendarView`).
class _AgendaItem {
  final DateTime when;
  final DateTime? endsAt;
  final String title;
  final String? subtitle;
  final String source; // 'crm' | 'outlook'
  final String? kind;
  final String? status;
  final String? tapType; // CRM entity type
  final String? tapId; // CRM entity id
  final String? joinUrl; // Outlook online-meeting join link
  final bool allDay;
  const _AgendaItem({
    required this.when,
    required this.title,
    required this.source,
    this.endsAt,
    this.subtitle,
    this.kind,
    this.status,
    this.tapType,
    this.tapId,
    this.joinUrl,
    this.allDay = false,
  });
}

/// CRM **Takvim / Ajanda — birleşik** — CRM aktiviteleri (`fn_crm_calendar`) +
/// bağlı Microsoft (Outlook) takvimi (`/me/calendarView`) tek listede, tarihe
/// göre gruplu, kaynak rozetli. "Benimkiler / Tümü" CRM kapsamını süzer;
/// "Outlook" çipi MS etkinliklerini gösterir/gizler. CRM satırı ilgili kayda
/// gider; Outlook satırı varsa toplantı linkini açar.
class CrmAgendaScreen extends StatefulWidget {
  const CrmAgendaScreen({super.key});

  @override
  State<CrmAgendaScreen> createState() => _CrmAgendaScreenState();
}

class _CrmAgendaScreenState extends State<CrmAgendaScreen> {
  final _svc = AggregateService();
  MicrosoftIntegrationService get _ms => sl<MicrosoftIntegrationService>();

  bool _mineOnly = true;
  bool _showOutlook = true;
  bool _loading = true;
  bool _msConnected = false;
  List<_AgendaItem> _items = [];

  static const _windowDays = 45;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: _windowDays));

    final crm = await _loadCrm(from, to);
    final conn = await _ms.getConnected();
    final outlook = conn != null ? await _loadOutlook(from, to) : <_AgendaItem>[];

    final merged = [...crm, if (_showOutlook) ...outlook]..sort((a, b) => a.when.compareTo(b.when));
    if (!mounted) return;
    setState(() {
      _msConnected = conn != null;
      _items = merged;
      _loading = false;
    });
  }

  Future<List<_AgendaItem>> _loadCrm(DateTime from, DateTime to) async {
    try {
      final rows = await _svc.rows('fn_crm_calendar', params: {
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
        'p_mine': _mineOnly,
      });
      return rows
          .map((r) {
            final d = DateTime.tryParse(r['event_date']?.toString() ?? '');
            if (d == null) return null;
            final related = r['related_name']?.toString();
            final owner = r['owner_name']?.toString();
            final sub = [related, owner].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
            return _AgendaItem(
              when: d,
              title: r['subject']?.toString() ?? '—',
              source: 'crm',
              subtitle: sub.isEmpty ? null : sub,
              kind: r['event_kind']?.toString(),
              status: r['status']?.toString(),
              tapType: r['entity_type']?.toString(),
              tapId: r['entity_id']?.toString(),
            );
          })
          .whereType<_AgendaItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<_AgendaItem>> _loadOutlook(DateTime from, DateTime to) async {
    final res = await _ms.graphCall('GET', '/me/calendarView', query: {
      'startDateTime': from.toUtc().toIso8601String(),
      'endDateTime': to.toUtc().toIso8601String(),
      '\$select': 'subject,start,end,location,isAllDay,onlineMeeting,organizer',
      '\$orderby': 'start/dateTime',
      '\$top': '100',
    });
    if (res == null || !res.ok || res.data is! Map) return [];
    final value = (res.data['value'] as List?) ?? const [];
    DateTime parse(String? s, bool allDay) {
      if (s == null) return DateTime.now();
      final iso = s.endsWith('Z') ? s : '${s}Z';
      final dt = DateTime.tryParse(iso) ?? DateTime.now();
      return allDay ? dt : dt.toLocal();
    }

    return value.map((raw) {
      final e = raw as Map;
      final allDay = (e['isAllDay'] ?? false) == true;
      final loc = (e['location'] as Map?)?['displayName'] as String?;
      final org = ((e['organizer'] as Map?)?['emailAddress'] as Map?)?['name'] as String?;
      final sub = [loc, org].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
      return _AgendaItem(
        when: parse((e['start'] as Map?)?['dateTime'] as String?, allDay),
        endsAt: parse((e['end'] as Map?)?['dateTime'] as String?, allDay),
        title: (e['subject'] as String?)?.trim().isNotEmpty == true ? e['subject'] as String : crmT('crm.mscal.no_subject', '(konusuz)'),
        source: 'outlook',
        subtitle: sub.isEmpty ? null : sub,
        joinUrl: (e['onlineMeeting'] as Map?)?['joinUrl'] as String?,
        allDay: allDay,
      );
    }).toList();
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: true, label: Text(crmT('crm.common.mine', 'Benimkiler'))),
                      ButtonSegment(value: false, label: Text(crmT('crm.common.all', 'Tümü'))),
                    ],
                    selected: {_mineOnly},
                    onSelectionChanged: (s) {
                      setState(() => _mineOnly = s.first);
                      _load();
                    },
                  ),
                ),
                if (_msConnected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  FilterChip(
                    avatar: Icon(Icons.event, size: 16, color: _showOutlook ? AppColors.primary : null),
                    label: Text(crmT('crm.agenda.outlook', 'Outlook')),
                    selected: _showOutlook,
                    onSelected: (v) {
                      setState(() => _showOutlook = v);
                      _load();
                    },
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: RefreshIndicator(onRefresh: _load, child: _buildBody())),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(child: AppEmptyState(icon: Icons.event_available_outlined, title: crmT('crm.agenda.empty', 'Yaklaşan etkinlik yok'))),
        ],
      );
    }

    final groups = <String, List<_AgendaItem>>{};
    for (final it in _items) {
      groups.putIfAbsent(AppClock.dayLabel(it.when), () => []).add(it);
    }

    final children = <Widget>[];
    groups.forEach((day, items) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
        child: Text(day, style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w700, color: AppColors.secondaryLabel(context))),
      ));
      children.addAll(items.map(_eventCard));
    });

    return ListView(padding: const EdgeInsets.only(bottom: AppSpacing.lg), children: children);
  }

  Widget _eventCard(_AgendaItem it) {
    final isOutlook = it.source == 'outlook';
    final time = it.allDay ? crmT('crm.mscal.all_day', 'Tüm gün') : AppClock.hm(it.when);

    void onTap() {
      if (isOutlook) {
        if ((it.joinUrl ?? '').isNotEmpty) UrlActions.openUrl(it.joinUrl!);
      } else if (it.tapType != null && it.tapId != null) {
        context.push('/entities/${it.tapType}/${it.tapId}');
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: AppCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isOutlook ? const Color(0xFF0F6CBD) : AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time, style: AppTypography.caption1.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    if (!it.allDay && it.endsAt != null)
                      Text(AppClock.hm(it.endsAt!), style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context)))
                    else if ((it.kind ?? '').isNotEmpty)
                      Text(it.kind!, style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context))),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isOutlook) ...[
                            const Icon(Icons.event, size: 13, color: Color(0xFF0F6CBD)),
                            const SizedBox(width: 4),
                          ],
                          Expanded(child: Text(it.title, style: AppTypography.subhead, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      if ((it.subtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(it.subtitle!, style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (isOutlook && (it.joinUrl ?? '').isNotEmpty)
                  const Icon(Icons.videocam_outlined, size: 18, color: Color(0xFF0F6CBD))
                else if (it.status != null && it.status!.isNotEmpty)
                  AppBadge(label: it.status!, variant: AppBadgeVariant.info, size: AppBadgeSize.small),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
