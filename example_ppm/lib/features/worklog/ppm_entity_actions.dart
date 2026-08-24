import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ppm_common.dart';

/// **PPM entity-detay domain aksiyonları** — generic entity_detail'e çekirdek
/// [EntityDetailExtensions] registry'si üzerinden PPM'e özel write-aksiyonu
/// (efor/worklog kaydı) ekler. `registerPpmScreens()`'ten bir kez çağrılır.
void registerPpmEntityActions() {
  // İş öğeleri (epic/story/task/sub_task) → efor kaydet.
  for (final t in const ['epic', 'story', 'task', 'sub_task']) {
    EntityDetailExtensions.registerActions(
      t,
      (ctx, e, reload) => [
        AppIconButton(
          icon: Icons.timer_outlined,
          onPressed: () => _logWork(ctx, e.id, reload),
        ),
      ],
    );
  }
}

SupabaseClient get _sb => sl<SupabaseClient>();

Future<void> _logWork(
    BuildContext ctx, String submissionId, Future<void> Function() reload) async {
  final ok = await showModalBottomSheet<bool>(
    context: ctx,
    isScrollControlled: true,
    builder: (_) => _LogWorkSheet(submissionId: submissionId),
  );
  if (ok == true) await reload();
}

/// Efor kaydı alt-sayfası (fn_ppm_log_work): harcanan saat + kalan tahmin + not.
class _LogWorkSheet extends StatefulWidget {
  final String submissionId;
  const _LogWorkSheet({required this.submissionId});

  @override
  State<_LogWorkSheet> createState() => _LogWorkSheetState();
}

class _LogWorkSheetState extends State<_LogWorkSheet> {
  final _hours = TextEditingController();
  final _remaining = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _hours.dispose();
    _remaining.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final hours = num.tryParse(_hours.text.trim().replaceAll(',', '.'));
    if (hours == null || hours <= 0 || _saving) return;
    setState(() => _saving = true);
    try {
      final remaining =
          num.tryParse(_remaining.text.trim().replaceAll(',', '.'));
      await _sb.rpc('fn_ppm_log_work', params: {
        'p_submission_id': widget.submissionId,
        'p_hours_spent': hours,
        if (remaining != null) 'p_remaining_estimate': remaining,
        if (_note.text.trim().isNotEmpty) 'p_note': _note.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ppmT('ppm.worklog.save_failed', 'Efor kaydedilemedi'))));
      }
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
          Text(ppmT('ppm.worklog.title', 'Efor Kaydet'),
              style: AppTypography.headline),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _hours,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: ppmT('ppm.worklog.hours', 'Harcanan saat *'),
                isDense: true,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _remaining,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText:
                    ppmT('ppm.worklog.remaining', 'Kalan tahmin (saat)'),
                isDense: true,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(
                labelText: ppmT('ppm.common.note', 'Not'),
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
                : Text(ppmT('ppm.common.save', 'Kaydet')),
          ),
        ],
      ),
    );
  }
}
