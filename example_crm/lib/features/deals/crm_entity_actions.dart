import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../crm_common.dart';
import '../contacts/contacts_service.dart' show CrmActivity;
import '../microsoft/entity_files_card.dart';

/// **CRM entity-detay domain aksiyonları** — generic `entity_detail`'e
/// (çekirdek `EntityDetailExtensions` registry'si üzerinden) CRM'e özel
/// write-aksiyonları + aktivite-feed bölümü ekler. `registerCrmScreens()`'ten
/// bir kez çağrılır. Backend RPC'leri web ile birebir (fn_crm_*).
void registerCrmEntityActions() {
  // Deal: sonraki-adım + aktivite-ekle
  EntityDetailExtensions.registerActions('deal', (ctx, e, reload) => [
        AppIconButton(
          icon: Icons.event_outlined,
          onPressed: () => _logNextStep(ctx, e.id, reload),
        ),
        AppIconButton(
          icon: Icons.add_comment_outlined,
          onPressed: () => _logActivity(ctx, dealId: e.id, reload: reload),
        ),
      ]);
  // Lead: aktivite-ekle
  EntityDetailExtensions.registerActions('lead', (ctx, e, reload) => [
        AppIconButton(
          icon: Icons.add_comment_outlined,
          onPressed: () => _logActivity(ctx, dealId: e.id, reload: reload),
        ),
      ]);
  // Activity: tamamla
  EntityDetailExtensions.registerActions('activity', (ctx, e, reload) => [
        AppIconButton(
          icon: Icons.check_circle_outline,
          onPressed: () => _completeActivity(ctx, e.id, reload),
        ),
      ]);
  // Dosyalar (OneDrive/SharePoint) + Aktivite-feed bölümü — deal / lead / company detayında.
  // registerSections tek-builder tutar (overwrite) → iki bölüm aynı builder'da.
  for (final t in const ['deal', 'lead', 'company']) {
    EntityDetailExtensions.registerSections(
      t,
      (ctx, e, reload) => [
        const SizedBox(height: AppSpacing.md),
        EntityFilesCard(entityType: t, entityId: e.id),
        const SizedBox(height: AppSpacing.md),
        _ActivityFeedSection(entityId: e.id),
      ],
    );
  }
}

SupabaseClient get _sb => sl<SupabaseClient>();

/// Tüm write-aksiyonları çekirdek [CrmActionsService] üzerinden gider
/// (tek, test-edilmiş RPC kaynağı — inline RPC string'i tekrar edilmez).
CrmActionsService get _actions => CrmActionsService(supabase: _sb);

Future<void> _logNextStep(
    BuildContext ctx, String dealId, Future<void> Function() reload) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: ctx,
    initialDate: now.add(const Duration(days: 1)),
    firstDate: now.subtract(const Duration(days: 1)),
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null) return;
  final ok = await _actions.logNextStep(dealId: dealId, dueDate: date);
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(ok
          ? crmT('crm.deal.next_step_saved', 'Sonraki adım kaydedildi ✓')
          : crmT('crm.common.save_failed', 'Kaydedilemedi'))));
  if (ok) await reload();
}

Future<void> _completeActivity(
    BuildContext ctx, String activityId, Future<void> Function() reload) async {
  final ok = await _actions.completeActivity(activityId: activityId);
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(ok
          ? crmT('crm.activity.completed', 'Aktivite tamamlandı ✓')
          : crmT('crm.common.action_failed', 'İşlem başarısız'))));
  if (ok) await reload();
}

Future<void> _logActivity(BuildContext ctx,
    {required String dealId, required Future<void> Function() reload}) async {
  final ok = await showModalBottomSheet<bool>(
    context: ctx,
    isScrollControlled: true,
    builder: (_) => _LogActivitySheet(dealId: dealId),
  );
  if (ok == true) await reload();
}

/// Deal/lead'e aktivite loglama alt-sayfası (fn_crm_log_activity).
class _LogActivitySheet extends StatefulWidget {
  final String dealId;
  const _LogActivitySheet({required this.dealId});

  @override
  State<_LogActivitySheet> createState() => _LogActivitySheetState();
}

class _LogActivitySheetState extends State<_LogActivitySheet> {
  final _subject = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'call';
  bool _saving = false;

  static const _types = ['call', 'meeting', 'email', 'task', 'note'];

  @override
  void dispose() {
    _subject.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_subject.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final ok = await _actions.logActivity(
      subject: _subject.text,
      activityType: _type,
      notes: _notes.text,
      relatedDealId: widget.dealId,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(crmT('crm.activity.add_failed', 'Aktivite eklenemedi'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(crmT('crm.activity.add_title', 'Aktivite Ekle'),
              style: AppTypography.headline),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final t in _types)
                ChoiceChip(
                  label: Text(t),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _subject,
            decoration: InputDecoration(
                labelText: crmT('crm.activity.subject', 'Konu *'),
                isDense: true,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
                labelText: crmT('crm.common.note', 'Not'),
                isDense: true,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(crmT('crm.common.save', 'Kaydet')),
          ),
        ],
      ),
    );
  }
}

/// Entity'ye (deal/lead/company) bağlı aktivite feed'i (fn_crm_activity_feed).
class _ActivityFeedSection extends StatefulWidget {
  final String entityId;
  const _ActivityFeedSection({required this.entityId});

  @override
  State<_ActivityFeedSection> createState() => _ActivityFeedSectionState();
}

class _ActivityFeedSectionState extends State<_ActivityFeedSection> {
  late Future<List<CrmActivity>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CrmActivity>> _load() async {
    final res = await _sb
        .rpc('fn_crm_activity_feed', params: {'p_entity_id': widget.entityId});
    return ((res as List?) ?? const [])
        .map((e) => CrmActivity.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CrmActivity>>(
      future: _future,
      builder: (context, snap) {
        final acts = snap.data ?? const <CrmActivity>[];
        if (snap.connectionState == ConnectionState.waiting || acts.isEmpty) {
          return const SizedBox.shrink();
        }
        return AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.timeline_outlined,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(crmT('crm.contact.activities', 'Aktiviteler'),
                      style: AppTypography.subhead),
                  const Spacer(),
                  Text('${acts.length}',
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.secondaryLabel(context))),
                ]),
                for (final a in acts.take(8)) _row(context, a),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, CrmActivity a) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBadge(
              label: a.type ?? 'not',
              variant: AppBadgeVariant.info,
              size: AppBadgeSize.small),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.subject,
                    style: AppTypography.footnote, maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (a.occurredAt != null)
                  Text(AppClock.date(a.occurredAt!),
                      style: AppTypography.caption2.copyWith(
                          color: AppColors.tertiaryLabel(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
