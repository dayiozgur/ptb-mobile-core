import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../crm_common.dart';

/// A pickable won/lost reason (`form_fields.options.items` of the deal form).
class DealReasonOption {
  final String value;
  final String label;
  const DealReasonOption(this.value, this.label);
}

/// Won/lost reason of a deal closed from mobile — web deal workspace
/// `confirmClose` parity:
///  * options come from the deal template's `won_reason` / `lost_reason`
///    select fields (`form_fields.options.items`), with the web's seeded
///    defaults as fallback;
///  * labels use `crm.deal_workspace.reason.<won|lost>.<value>` when that key
///    exists, else the option label;
///  * persisted with `fn_crm_set_deal_reason(p_deal_id, p_field_code,
///    p_reason)` (SECURITY DEFINER; writes form_field_values + metadata).
class CrmDealReason {
  CrmDealReason._();

  /// A final status code → reason field (web: `won` → won_reason, any other
  /// final status → lost_reason).
  static String fieldFor(String finalStatusCode) =>
      finalStatusCode == 'won' ? 'won_reason' : 'lost_reason';

  static const Map<String, List<String>> defaults = {
    'won_reason': ['budget', 'authority', 'relationship', 'product_fit', 'other'],
    'lost_reason': [
      'price',
      'competitor',
      'timing',
      'no_budget',
      'no_response',
      'no_decision'
    ],
  };

  static String _humanize(String v) => EntityStatusLabels.humanize(v);

  /// Options from the field rows (`{code, options:{items:[{label,value}]}}`),
  /// translated; seeded defaults when the field has no items.
  static List<DealReasonOption> optionsFrom(
    List<Map<String, dynamic>> fieldRows,
    String field,
    String Function(String key) translate,
  ) {
    final kind = field == 'won_reason' ? 'won' : 'lost';
    String label(String value, String? dbLabel) {
      final key = 'crm.deal_workspace.reason.$kind.$value';
      final t = translate(key);
      if (t.isNotEmpty && t != key) return t;
      return (dbLabel != null && dbLabel.trim().isNotEmpty)
          ? dbLabel.trim()
          : _humanize(value);
    }

    for (final r in fieldRows) {
      if (r['code'] != field) continue;
      final opts = r['options'];
      final items = opts is Map ? opts['items'] : null;
      if (items is List && items.isNotEmpty) {
        return [
          for (final it in items)
            if (it is Map && it['value'] is String)
              DealReasonOption(it['value'] as String,
                  label(it['value'] as String, it['label'] as String?)),
        ];
      }
    }
    return [for (final v in defaults[field] ?? const <String>[]) DealReasonOption(v, label(v, null))];
  }

  /// Field definitions of the deal's template (empty on error → defaults).
  static Future<List<Map<String, dynamic>>> loadFieldRows(
      SupabaseClient sb, String dealId) async {
    try {
      final deal = await sb
          .from('form_submissions')
          .select('form_template_id')
          .eq('id', dealId)
          .maybeSingle();
      final tpl = deal?['form_template_id'] as String?;
      if (tpl == null) return const [];
      final res = await sb
          .from('form_fields')
          .select('code, options, form_sections!inner(form_template_id)')
          .eq('form_sections.form_template_id', tpl)
          .inFilter('code', ['won_reason', 'lost_reason']);
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      Logger.error('deal reason fields ($dealId) hata', e);
      return const [];
    }
  }

  /// `fn_crm_set_deal_reason` — throws on failure.
  static Future<void> save(
      SupabaseClient sb, String dealId, String field, String reason) async {
    await sb.rpc('fn_crm_set_deal_reason', params: {
      'p_deal_id': dealId,
      'p_field_code': field,
      'p_reason': reason,
    });
  }

  /// Ask for the reason (required). Returns the option value or null when
  /// the user cancels.
  static Future<String?> prompt(
    BuildContext context, {
    required bool won,
    required List<DealReasonOption> options,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dctx) => _ReasonDialog(won: won, options: options),
    );
  }

  /// Full flow for a deal moving to [finalStatus]: load options, prompt, and
  /// return a callback that saves the reason AFTER the transition succeeded
  /// (null when the user cancelled → the transition must not run).
  static Future<Future<void> Function(BuildContext context)?> collect(
    BuildContext context, {
    required String dealId,
    required String finalStatus,
    SupabaseClient? supabase,
    Future<List<Map<String, dynamic>>> Function()? loadRows,
    Future<void> Function(String field, String reason)? saver,
  }) async {
    final sb = supabase ?? (sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null);
    final field = fieldFor(finalStatus);
    final rows = loadRows != null
        ? await loadRows()
        : (sb == null ? const <Map<String, dynamic>>[] : await loadFieldRows(sb, dealId));
    if (!context.mounted) return null;
    final options = optionsFrom(rows, field, sl<LocalizationService>().translate);
    final reason = await prompt(context, won: field == 'won_reason', options: options);
    if (reason == null || reason.isEmpty) return null;
    return (BuildContext ctx) async {
      try {
        if (saver != null) {
          await saver(field, reason);
        } else if (sb != null) {
          await save(sb, dealId, field, reason);
        }
      } catch (e) {
        Logger.error('deal reason save ($dealId) hata', e);
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text(crmT('crm.deal_workspace.reason_save_error',
                  'Durum güncellendi ancak neden kaydedilemedi.'))));
        }
      }
    };
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.won, required this.options});
  final bool won;
  final List<DealReasonOption> options;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  String? _selected;
  bool _attempted = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(crmT('crm.deal_workspace.close_title', 'Fırsatı kapat')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.won
                ? crmT('crm.deal_workspace.close_won_prompt',
                    'Bu fırsatı neden kazandınız?')
                : crmT('crm.deal_workspace.close_lost_prompt',
                    'Bu fırsat neden kaybedildi?')),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final o in widget.options)
                    RadioListTile<String>(
                      key: ValueKey('deal-reason-${o.value}'),
                      value: o.value,
                      title: Text(o.label),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (_attempted && _selected == null)
              Text(
                crmT('crm.deal_workspace.reason_required',
                    'Lütfen bir neden seçin.'),
                style: AppTypography.caption1.copyWith(color: AppColors.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(crmT('crm.common.cancel', 'Vazgeç'))),
        TextButton(
          key: const Key('deal-reason-confirm'),
          onPressed: () {
            if (_selected == null) {
              setState(() => _attempted = true);
              return;
            }
            Navigator.of(context).pop(_selected);
          },
          child: Text(crmT('fixflow.kanban.confirm', 'Onayla')),
        ),
      ],
    );
  }
}
