import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';

/// **Microsoft (Outlook) calendar** — a live view of the connected user's own
/// Outlook events over the next weeks, read directly through graph-proxy
/// (`GET /me/calendarView`, Calendars.ReadWrite). This shows the real Microsoft
/// calendar (not the CRM activity feed), grouped by day, so "my calendar synced
/// with Microsoft" is answered directly rather than via the indirect
/// activity-sync path.
class MsCalendarScreen extends StatefulWidget {
  const MsCalendarScreen({super.key});
  @override
  State<MsCalendarScreen> createState() => _MsCalendarScreenState();
}

class _Event {
  final String subject;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? location;
  final String? joinUrl;
  final String? organizer;
  const _Event(this.subject, this.start, this.end, this.allDay, this.location, this.joinUrl, this.organizer);
}

class _MsCalendarScreenState extends State<MsCalendarScreen> {
  MicrosoftIntegrationService get _svc => sl<MicrosoftIntegrationService>();
  List<_Event> _events = const [];
  bool _loading = true;
  bool _connected = true;
  static const int _weeks = 4;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _parse(String? s, {required bool utc}) {
    if (s == null) return DateTime.now();
    // Graph returns naive local-to-UTC dateTimes; calendarView defaults to UTC.
    final iso = s.endsWith('Z') ? s : '${s}Z';
    final dt = DateTime.tryParse(iso) ?? DateTime.now();
    return utc ? dt.toLocal() : dt;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final conn = await _svc.getConnected();
    if (!mounted) return;
    if (conn == null) {
      setState(() {
        _connected = false;
        _loading = false;
      });
      return;
    }
    final now = DateTime.now().toUtc();
    final res = await _svc.graphCall('GET', '/me/calendarView', query: {
      'startDateTime': now.subtract(const Duration(days: 1)).toIso8601String(),
      'endDateTime': now.add(const Duration(days: 7 * _weeks)).toIso8601String(),
      '\$select': 'subject,start,end,location,isAllDay,onlineMeeting,organizer',
      '\$orderby': 'start/dateTime',
      '\$top': '100',
    });
    if (!mounted) return;
    if (res == null || !res.ok || res.data is! Map) {
      setState(() {
        _events = const [];
        _connected = true;
        _loading = false;
      });
      return;
    }
    final value = (res.data['value'] as List?) ?? const [];
    final list = <_Event>[];
    for (final raw in value) {
      final e = raw as Map;
      final allDay = (e['isAllDay'] ?? false) == true;
      list.add(_Event(
        (e['subject'] as String?)?.trim().isNotEmpty == true ? e['subject'] as String : crmT('crm.mscal.no_subject', '(konusuz)'),
        _parse((e['start'] as Map?)?['dateTime'] as String?, utc: !allDay),
        _parse((e['end'] as Map?)?['dateTime'] as String?, utc: !allDay),
        allDay,
        (e['location'] as Map?)?['displayName'] as String?,
        (e['onlineMeeting'] as Map?)?['joinUrl'] as String?,
        ((e['organizer'] as Map?)?['emailAddress'] as Map?)?['name'] as String?,
      ));
    }
    setState(() {
      _events = list;
      _connected = true;
      _loading = false;
    });
  }

  Map<String, List<_Event>> get _grouped {
    final map = <String, List<_Event>>{};
    for (final e in _events) {
      final key = AppClock.date(e.start);
      (map[key] ??= []).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: crmT('crm.mscal.title', 'Microsoft Takvimi'),
      showBackButton: true,
      actions: [AppIconButton(icon: Icons.refresh, onPressed: _load)],
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : (!_connected
              ? Center(
                  child: AppEmptyState(
                      icon: Icons.event_busy_outlined,
                      title: crmT('crm.mscal.not_connected', 'Microsoft hesabı bağlı değil')))
              : (_events.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(children: [
                        const SizedBox(height: 120),
                        Center(
                            child: AppEmptyState(
                                icon: Icons.event_available_outlined,
                                title: crmT('crm.mscal.empty', 'Bu dönemde etkinlik yok'))),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: AppSpacing.screenPadding,
                        children: _grouped.entries.expand((g) => [
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
                                child: Text(g.key, style: AppTypography.headline),
                              ),
                              ...g.value.map(_eventTile),
                            ]).toList(),
                      ),
                    ))),
    );
  }

  Widget _eventTile(_Event e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.allDay ? crmT('crm.mscal.all_day', 'Tüm gün') : AppClock.hm(e.start),
                      style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w700)),
                  if (!e.allDay)
                    Text(AppClock.hm(e.end),
                        style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context))),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.subject, style: AppTypography.body),
                    if ((e.location ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(children: [
                          Icon(Icons.location_on_outlined, size: 13, color: AppColors.tertiaryLabel(context)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(e.location!, style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    if ((e.organizer ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('${crmT('crm.mscal.organizer', 'Düzenleyen')}: ${e.organizer}',
                            style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
              if ((e.joinUrl ?? '').isNotEmpty)
                AppIconButton(
                  icon: Icons.videocam_outlined,
                  tooltip: crmT('crm.teams.open', 'Aç'),
                  onPressed: () => UrlActions.openUrl(e.joinUrl!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
