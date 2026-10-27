import 'package:flutter/material.dart';

import '../../../core/alarm/alarm_model.dart';
import '../../../core/alarm/alarm_service.dart';
import '../../../core/alarm/alarm_ticket_model.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/priority/priority_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/utils/logger.dart';

/// Alarmdan FixFlow iş emri açma formu (bottom sheet).
///
/// Web PMS alarm çözüm diyaloğundaki "FixFlow iş emri oluştur" akışının mobil
/// karşılığı; aynı RPC'ler (`fn_pms_alarm_create_ticket` /
/// `fn_pms_alarm_linked_ticket` / `fn_pms_alarm_ticket_route_preview`).
///
/// * Konu alarm adıyla, açıklama alarm özetiyle (kod, cihaz, lokasyon,
///   başlangıç, öncelik) önceden doldurulur; ikisi de düzenlenebilir.
/// * Öncelik / disiplin / SLA / bakım firması yönlendirmesi SUNUCUDA alarmdan
///   türetilir (RPC öncelik parametresi almaz) → öncelik salt-okunur gösterilir.
/// * Alarmın AÇIK (kapanmamış) bağlı iş emri varsa yeni iş emri açılmaz; mevcut
///   iş emri numarası gösterilir (sahada çift kayıt önleme).
/// * FixFlow üyeliği yoksa (`fixflow_not_entitled`) bilgilendirme gösterilir.
///
/// Başarıda sheet [AlarmCreatedTicket] ile kapanır; iptalde null.
class AlarmTicketSheet extends StatefulWidget {
  final Alarm alarm;
  final Priority? priority;

  /// Varsa açıklamaya eklenen lokasyon / saha adı.
  final String? siteName;

  const AlarmTicketSheet({
    super.key,
    required this.alarm,
    this.priority,
    this.siteName,
  });

  /// Sheet'i aç; oluşturulan iş emrini (veya iptalde null) döndürür.
  static Future<AlarmCreatedTicket?> show(
    BuildContext context, {
    required Alarm alarm,
    Priority? priority,
    String? siteName,
  }) {
    return showModalBottomSheet<AlarmCreatedTicket>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (_) => AlarmTicketSheet(
        alarm: alarm,
        priority: priority,
        siteName: siteName,
      ),
    );
  }

  @override
  State<AlarmTicketSheet> createState() => _AlarmTicketSheetState();
}

/// `{{k}}` (web/ngx-translate) ve `{k}` (mobil) yer tutucularını doldurur.
String fillTicketPlaceholders(String text, Map<String, String> params) {
  var out = text;
  params.forEach((k, v) {
    out = out.replaceAll('{{$k}}', v).replaceAll('{$k}', v);
  });
  return out;
}

/// Alarmdan iş emri açıklaması: "Etiket: değer" satırları (boşlar atlanır).
/// Web `buildAlarmTicketDescription` ile aynı anahtarlar.
String buildAlarmTicketDescription(
  Alarm alarm, {
  Priority? priority,
  String? siteName,
  required String Function(String key) translate,
}) {
  final device = [alarm.variableName, alarm.variableDescription]
      .where((v) => v != null && v.trim().isNotEmpty)
      .join(' / ');
  final lines = <(String, String?)>[
    ('common.code', alarm.code),
    ('pms.alarm.col.location', siteName),
    ('pms.alarm.fixflow.device', device),
    (
      'pms.alarm.col.start',
      alarm.startTime != null
          ? AppClock.dateTimeSeconds(alarm.startTime!)
          : null
    ),
    ('common.priority', priority?.localizedLabel(translate)),
    ('common.description', alarm.description),
  ];
  return lines
      .where((l) => l.$2 != null && l.$2!.trim().isNotEmpty)
      .map((l) => '${translate(l.$1)}: ${l.$2!.trim()}')
      .join('\n');
}

class _AlarmTicketSheetState extends State<AlarmTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subject;
  late final TextEditingController _description;

  LocalizationService get _loc => sl<LocalizationService>();
  AlarmService get _alarms => sl<AlarmService>();

  bool _loadingLinked = true;
  bool _linkedFailed = false;
  List<AlarmLinkedTicket> _linked = const [];

  bool _loadingRoute = true;
  bool _routeFailed = false;
  AlarmTicketRoutePreview? _route;

  bool _notEntitled = false;
  bool _creating = false;
  bool _createFailed = false;

  @override
  void initState() {
    super.initState();
    final name = widget.alarm.name?.trim();
    _subject = TextEditingController(
      text: (name != null && name.isNotEmpty)
          ? name
          : _loc.translate('pms.alarm.unnamed'),
    );
    _description = TextEditingController(
      text: buildAlarmTicketDescription(
        widget.alarm,
        priority: widget.priority,
        siteName: widget.siteName,
        translate: _loc.translate,
      ),
    );
    _loadLinked();
    _loadRoute();
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadLinked() async {
    try {
      final list = await _alarms.getLinkedTickets(widget.alarm.id);
      if (!mounted) return;
      setState(() {
        _linked = list;
        _loadingLinked = false;
      });
    } catch (e) {
      Logger.error('Alarm linked tickets failed', e);
      if (!mounted) return;
      setState(() {
        _linkedFailed = true;
        _loadingLinked = false;
      });
    }
  }

  Future<void> _loadRoute() async {
    try {
      final r = await _alarms.getTicketRoutePreview(widget.alarm.id);
      if (!mounted) return;
      setState(() {
        _route = r;
        _loadingRoute = false;
      });
    } catch (e) {
      Logger.error('Alarm ticket route preview failed', e);
      if (!mounted) return;
      setState(() {
        _routeFailed = true;
        _loadingRoute = false;
      });
    }
  }

  AlarmLinkedTicket? get _openLinked {
    for (final t in _linked) {
      if (t.isOpen) return t;
    }
    return null;
  }

  bool get _canCreate =>
      !_creating && !_loadingLinked && !_notEntitled && _openLinked == null;

  Future<void> _create() async {
    if (!_canCreate) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _creating = true;
      _createFailed = false;
    });
    try {
      final ticket = await _alarms.createFixflowTicket(
        widget.alarm.id,
        subject: _subject.text,
        description: _description.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(ticket);
    } catch (e) {
      Logger.error('Alarm → FixFlow ticket failed', e);
      if (!mounted) return;
      setState(() {
        _creating = false;
        if (isFixflowNotEntitled(e)) {
          _notEntitled = true;
        } else {
          _createFailed = true;
        }
      });
    }
  }

  String _labelOr(String key, String fallback) {
    final t = _loc.translate(key);
    return (t.isNotEmpty && t != key) ? t : fallback;
  }

  String? get _priorityLabel {
    if (widget.priority != null) {
      return widget.priority!.localizedLabel(_loc.translate);
    }
    final code = _route?.priorityCode;
    if (code == null || code.isEmpty) return null;
    return _labelOr(priorityLabelKey(code), code);
  }

  String _routeSentence(AlarmTicketRoutePreview p) {
    final target = p.targetName ?? '—';
    final team = p.teamName ?? '';
    String key;
    switch (p.mode) {
      case AlarmTicketRouteMode.external:
        key = team.isNotEmpty
            ? 'pms.alarm_ticket.route.external_team'
            : 'pms.alarm_ticket.route.external';
      case AlarmTicketRouteMode.internal:
        key = team.isNotEmpty
            ? 'pms.alarm_ticket.route.internal'
            : 'pms.alarm_ticket.route.internal_no_team';
      case AlarmTicketRouteMode.none:
        key = 'pms.alarm_ticket.route.none';
    }
    final head = p.contractorName != null && p.mode != AlarmTicketRouteMode.none
        ? '${p.contractorName} — '
        : '';
    return head +
        fillTicketPlaceholders(
            _loc.translate(key), {'target': target, 'team': team});
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final loc = _loc;
    final secondary = TextStyle(
      fontSize: 13,
      color: AppColors.textSecondary(brightness),
    );
    final open = _openLinked;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.systemGray4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.confirmation_number_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        loc.translate('pms.alarm.fixflow.create'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Yönlendirme (bakım firması / ekip)
                if (_loadingRoute)
                  Text(loc.translate('pms.alarm_ticket.route.loading'),
                      style: secondary)
                else if (_routeFailed)
                  Text(loc.translate('pms.alarm_ticket.error.preview'),
                      style: secondary)
                else if (_route != null) ...[
                  Text(_routeSentence(_route!),
                      key: const ValueKey('alarm-ticket-route'),
                      style: secondary),
                  if (_route!.ambiguous)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                          loc.translate('pms.alarm_ticket.route.ambiguous'),
                          style: secondary),
                    ),
                ],

                // Öncelik (sunucu alarmdan yazar → salt-okunur)
                if (_priorityLabel != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${loc.translate('common.priority')}: $_priorityLabel',
                    key: const ValueKey('alarm-ticket-priority'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.priority?.displayColor ??
                          AppColors.textPrimary(brightness),
                    ),
                  ),
                ],

                // Bağlı iş emirleri
                if (_loadingLinked) ...[
                  const SizedBox(height: AppSpacing.md),
                  const LinearProgressIndicator(),
                ] else if (_linkedFailed) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(loc.translate('pms.alarm_ticket.error.linked'),
                      style: secondary),
                ] else if (_linked.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    loc.translate('pms.alarm.fixflow.linked_tickets'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final t in _linked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        [
                          t.displayCode,
                          if (t.subject != null && t.subject!.isNotEmpty)
                            t.subject!,
                          loc.translate(t.isOpen
                              ? 'pms.alarm_ticket.linked.open'
                              : 'pms.alarm_ticket.linked.closed'),
                        ].join(' · '),
                        style: secondary,
                      ),
                    ),
                ],

                if (open != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Notice(
                    key: const ValueKey('alarm-ticket-already-linked'),
                    icon: Icons.link,
                    color: AppColors.info,
                    text: fillTicketPlaceholders(
                      loc.translate('pms.alarm.fixflow.already_linked'),
                      {'code': open.displayCode},
                    ),
                  ),
                ],

                if (_notEntitled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Notice(
                    key: const ValueKey('alarm-ticket-not-entitled'),
                    icon: Icons.lock_outline,
                    color: AppColors.warning,
                    title:
                        loc.translate('pms.alarm.fixflow.not_entitled_title'),
                    text: loc.translate('pms.alarm.fixflow.not_entitled'),
                  ),
                ],

                if (open == null && !_notEntitled) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const ValueKey('alarm-ticket-subject'),
                    controller: _subject,
                    enabled: !_creating,
                    maxLength: 250,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: loc.translate('common.subject'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? loc.translate('common.required')
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    key: const ValueKey('alarm-ticket-description'),
                    controller: _description,
                    enabled: !_creating,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: loc.translate('common.description'),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],

                if (_createFailed) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    loc.translate('pms.alarm.fixflow.create_error'),
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.error),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _creating
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(loc.translate('common.cancel')),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const ValueKey('alarm-ticket-submit'),
                        onPressed: _canCreate ? _create : null,
                        icon: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.add_task),
                        label: Text(loc.translate(_creating
                            ? 'pms.alarm.fixflow.creating'
                            : 'common.create')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? title;
  final String text;

  const _Notice({
    super.key,
    required this.icon,
    required this.color,
    this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!,
                      style:
                          TextStyle(fontWeight: FontWeight.w600, color: color)),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
